class Tournament < ActiveRecord::Base
  extend Util::Pagination

  FEDS = ICU::Federation.codes
  TIEBREAK = "(?:#{ICU::TieBreak.rules.map(&:id).join('|')})"

  has_one    :upload
  has_many   :players, :include => :results
  belongs_to :user

  default_scope order("start DESC, finish DESC, created_at DESC")

  attr_accessible :name, :start, :finish, :fed, :city, :site, :arbiter, :deputy, :time_control, :tie_breaks

  before_validation :normalise_attributes

  validates_presence_of     :name, :start
  validates_date            :start, :after => '1900-01-01'
  validates_date            :finish, :after => '1900-01-01', :allow_nil => true
  validate                  :finish_on_or_after_start
  validates_inclusion_of    :fed, :in => FEDS, :allow_nil => true, :message => '(%{value}) is invalid'
  validates_format_of       :tie_breaks, :with => /^#{TIEBREAK}(?:,#{TIEBREAK})*$/, :allow_nil => true
  validates_numericality_of :user_id, :only_integer => true, :greater_than => 0, :message => "(%{value}) is invalid"

  # Build a Tournament from an icu_tournament object parsed from an uploaded file.
  def self.build_from_icut(icut, upload=nil)
    self.new do |tournament|
      %w{name start finish rounds fed city site arbiter deputy time_control}.each do |attr|
        tournament.send("#{attr}=", icut.send(attr)) unless icut.send(attr).blank?
      end
      %w{name start finish}.each do |key|
        tournament.send("original_#{key}=", icut.send(key)) unless icut.send(key).blank?
      end
      unless icut.tie_breaks.size == 0
        tournament.original_tie_breaks = tournament.tie_breaks = icut.tie_breaks.join(',')
      end
      tournament.upload = upload if upload
      icut.players.each do |icup|
        Player.build_from_icut(icup, tournament)
      end
    end
  end

  # Search and paginate.
  def self.search(params, path)
    matches = Tournament.includes(:upload)
    if params[:name].present?
      params[:name].strip.split(/\s+/).each do |term|
        matches = matches.where("tournaments.name LIKE ?", "%#{term}%")
      end
    end
    matches = matches.joins(:players).where(:players => { :icu_id => params[:icu_id].to_i }) if params[:icu_id].to_i > 0
    matches = matches.where(:user_id => params[:user_id].to_i) if params[:user_id].to_i > 0
    paginate(matches, path, params)
  end

  # The latest tournaments.
  def self.latest(limit=10)
    Tournament.limit(limit)
  end

  # Return an ICU::Tournament instance built from a database Tournament.
  def icu_tournament(opts={})
    icut = ICU::Tournament.new(name, start)
    %w{finish rounds fed city site arbiter deputy time_control}.each do |attr|
      icut.send("#{attr}=", self.send(attr)) unless self.send(attr).blank?
    end
    icut.tie_breaks = tie_breaks.split(',') unless tie_breaks.blank?
    players.each do |p|
      opt = { :id => p.icu_id, :rating => p.icu_rating }
      [:fed, :fide_id, :fide_rating, :gender, :rank, :title, :dob].each { |attr| opt[attr] = p.send(attr) }
      icut.add_player(ICU::Player.new(p.first_name, p.last_name, p.id, opt))
    end
    players.each do |p|
      p.results.each do |r|
        opt = { :opponent => r.opponent_id }
        [:colour, :rateable].each { |attr| opt[attr] = r.send(attr) }
        icut.add_result(ICU::Result.new(r.round, p.id, r.score, opt))
      end
    end
    icut.renumber(opts[:renumber]) if opts[:renumber]
    icut
  end

  # The available formats in which to export the tournament.
  def export_formats
    formats = Upload::FORMATS.reject { |f| f.last == "SwissPerfect" }
  end

  # Export the tournament to a text format.
  def export(params)
    format, order, opts = export_params(params)
    begin
      icut = icu_tournament(:renumber => order)
      icut.serialize(format, opts)
    rescue => e
      e.message
    end
  end

  # Change the arbitrary player numbers for opponents in results to the corresponding Player IDs.
  # Should only need to be called after an initial upload has suceeded.
  def renumber_opponents
    map = players.inject({}) { |h, p| h[p.num] = p.id; h }
    players.each do |p|
      p.results.each do |r|
        r.update_attribute(:opponent_id, map[r.opponent_id]) if r.opponent_id != map[r.opponent_id]
      end
    end
  end

  # The name and year of a tournament.
  def long_name
    year = start.year.to_s
    return name if name.include?(year)
    year+= "-#{finish.year.to_s[2..3]}" if finish && finish.year > start.year
    "#{name} (#{year})"
  end

  # Players in rank order or, if the ranking is invalid, in name order.
  def ordered_players(rankable=nil)
    rankable ||= self.rankable
    players.order(rankable ? "rank" : "last_name, first_name")
  end

  # Return a menu of all possible opponents for a player given a round.
  # The round information is supplied as part of an existing Result object.
  def possible_opponents(result)
    available = players.select do |p|
      if result.player == p
        false
      elsif result.opponent == p
        true
      else
        busy = p.result_in_round(result.round)
        !(busy && busy.opponent)
      end
    end
    available.map! { |p| [p.name, p.id.to_s] }
    available.sort! { |a,b| a[0] <=> b[0] }
    available.unshift(['None', ''])
    available
  end

  # Return a hash describing the players' ranking numbers.
  def ranking_summary
    r2s, min, max, dup = Hash.new, nil, nil, false
    players.reject{ |p| p.rank.nil? }.each do |p|
      dup = true if r2s[p.rank]
      r2s[p.rank] = p.score
      min = p.rank if min.nil? || p.rank < min
      max = p.rank if max.nil? || p.rank > max
    end
    # What type of invalidity do we have, if any?
    invalid = case
      when r2s.size == 0                  then :none
      when r2s.size < players.size && dup then "duplicates"
      when r2s.size < players.size        then "some missing"
      when min != 1                       then "should start at 1"
      when max != players.size            then "should end with #{players.size}"
      else (min..max).find { |r| r > min && r2s[r-1] < r2s[r] }
    end
    # Turn the invalidity into a boolean, symbol and string.
    # Calling code should not rely on the string value which is for the UI and may change.
    case invalid
    when nil
      symbol = :valid
      string = "Valid"
    when :none
      symbol = :none
      string = "Unranked"
    when Fixnum
      symbol = :inconsistent
      string = "Inconsistent (e.g. #{invalid - 1}:#{r2s[invalid - 1]}, #{invalid}:#{r2s[invalid]})"
    else
      symbol = :invalid
      string = "Invalid (#{invalid})"
    end
    {
      :valid       => symbol == :valid,
      :rankable    => symbol == :valid || symbol == :inconsistent,
      :type        => symbol,
      :description => string,
    }
  end

  # Return merely whether the tournament rank is valid or not.
  def rankable
    ranking_summary[:valid]
  end

  # Rank or rerank the tournament using it's current tie break rules.
  def rank
    icut = icu_tournament
    icut.rerank
    players.each do |player|
      icup = icut.player(player.id)
      player.update_attribute(:rank, icup.rank) unless player.rank == icup.rank
    end
  end

  # Return an ordered array of pairs where the first item is a TieBreak instance
  # and the second is true or false according to whether the tie break is selected
  # for the current tournament.
  def tie_break_selections
    selected = (tie_breaks || '').split(',')
    selections = []
    used = Hash.new
    selected.each do |tb|
      rule = ICU::TieBreak.identify(tb)
      if rule
        selections << [rule, true]
        used[rule.id] = true
      else
        logger.error("bad tie break identifier (#{tb}) in tournament #{id}")
      end
    end
    ICU::TieBreak.rules.each do |rule|
      selections << [rule, false] unless used[rule.id]
    end
    selections
  end

  # Return a string describing the first (by default) or all errors in a tournament.
  # Return nil if there are no errors.
  def error_summary(short=true)
    samples = Array.new
    players.each do |p|
      p.results.each do |r|
        samples.push "result (for #{p.name} in R#{r.round}): #{r.errors.full_messages.join(', ')}" unless r.valid?
      end
      samples.push "player (#{p.name}): #{p.errors.full_messages.join(', ')}" unless p.valid?
    end
    samples.push "tournament: #{errors.full_messages.join(', ')}" unless valid?
    return nil if samples.empty?
    return samples.first if short
    samples.join("; ")
  end

  def original_data
    data = Array.new
    %w{name start finish tie_breaks}.each do |key|
      val = self.send("original_#{key}")
      next if val.blank?
      val.gsub!(/,/, "|") if key == "tie_breaks"
      data.push val
    end
    data.join(", ")
  end

  private

  def finish_on_or_after_start
    errors.add(:finish, "finish can't be before start") if finish && finish < start
  end

  def normalise_attributes
    %w{start finish fed city site arbiter deputy time_control tie_breaks}.each do |attr|
      self.send("#{attr}=", nil) if self.send(attr).to_s.match(/^\s*$/)
    end
  end

  # Translate from CGI params to export options.
  def export_params(params)
    format = %w{Krause SPExport ForeignCSV}.find { |f| f == params[:type] } || 'Krause'
    order = %w{rank name}.find { |o| o == params[:order] }
    params = params[format.downcase]
    params = Hash.new unless params.respond_to?(:keys)
    opts = Hash.new
    case format
    when "Krause"
      opts[:fide] = true if params["fide"] == "1"
      opts[:only] = Array.new
      options = ICU::Tournament::Krause::OPTIONS.map(&:first).inject({}) { |m, o| m[o] = true; m }
      params.keys.each do |nam|
        next if nam.match(/^(num|name)$/)
        key = nam.to_sym
        next unless options.has_key?(key)
        opts[:only] << key
      end
    when "SPExport"
      opts[:only] = Array.new
      params.keys.each do |nam|
        next if nam.match(/^(num|name)$/)
        key = nam.to_sym
        next unless ICU::Tournament::SPExport::KEY2NAM.has_key?(key)
        opts[:only] << key
      end
    end
    [format, order, opts]
  end
end
