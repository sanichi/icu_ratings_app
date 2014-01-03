# == Schema Information
#
# Table name: tournaments
#
#  id                     :integer(4)      not null, primary key
#  name                   :string(255)
#  city                   :string(255)
#  site                   :string(255)
#  arbiter                :string(255)
#  deputy                 :string(255)
#  tie_breaks             :string(255)
#  time_control           :string(255)
#  start                  :date
#  finish                 :date
#  fed                    :string(3)
#  rounds                 :integer(1)
#  user_id                :integer(4)
#  original_name          :string(255)
#  original_tie_breaks    :string(255)
#  original_start         :date
#  original_finish        :date
#  created_at             :datetime
#  updated_at             :datetime
#  status                 :string(255)     default("ok")
#  stage                  :string(20)      default("initial")
#  rorder                 :integer(4)
#  reratings              :integer(2)      default(0)
#  next_tournament_id     :integer(4)
#  last_tournament_id     :integer(4)
#  old_last_tournament_id :integer(4)
#  first_rated            :datetime
#  last_rated             :datetime
#  last_rated_msec        :integer(2)
#  last_signature         :string(32)
#  curr_signature         :string(32)
#  locked                 :boolean(1)      default(FALSE)
#  iterations1            :integer(2)      default(0)
#  iterations2            :integer(2)      default(0)
#  rerate                 :boolean(1)      default(FALSE)
#

require "icu/error"

class Tournament < ActiveRecord::Base
  extend ICU::Util::Pagination

  FEDS = ICU::Federation.codes
  STAGE = %w[initial ready queued rated]
  TIEBREAK = "(?:#{ICU::TieBreak.rules.map(&:id).join('|')})"

  has_one    :upload, dependent: :destroy
  has_many   :players, dependent: :destroy
  belongs_to :user
  belongs_to :last_tournament, class_name: "Tournament"
  belongs_to :next_tournament, class_name: "Tournament"

  scope :ordered, -> { order("finish DESC, start DESC, rorder DESC, tournaments.name") }

  before_validation :normalise_attributes, :guess_finish, :requeue

  validates_presence_of     :name, :start, :status
  validates_date            :start, after: "1900-01-01", on_or_before: :today
  validates_date            :finish, after: "1900-01-01", on_or_before: :today
  validate                  :finish_on_or_after_start
  validates_inclusion_of    :fed, in: FEDS, allow_nil: true, message: '(%{value}) is invalid'
  validates_inclusion_of    :stage, in: STAGE, message: '(%{value}) is invalid'
  validates_format_of       :tie_breaks, with: /\A#{TIEBREAK}(?:,#{TIEBREAK})*\z/, allow_nil: true
  validates_numericality_of :user_id, :rounds, only_integer: true, greater_than: 0, message: "(%{value}) is invalid"
  validates_numericality_of :rorder, :fide_id, only_integer: true, greater_than: 0, allow_nil: true, message: "(%{value}) is invalid"
  validates :iterations1, :iterations2, numericality: { only_integer: true, greater_than_or_equal: 0 }

  # Build a Tournament from an icu_tournament object parsed from an uploaded file.
  def self.build_from_icut(icut, upload=nil)
    self.new do |tournament|
      %w[name start finish rounds fed city site arbiter deputy time_control].each do |attr|
        tournament.send("#{attr}=", icut.send(attr)) unless icut.send(attr).blank?
      end
      %w[name start finish].each do |key|
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
    matches = ordered

    # Name or parts thereof.
    if params[:name].present?
      params[:name].strip.split(/\s+/).each do |term|
        matches = matches.where("tournaments.name LIKE ?", "%#{term}%")
      end
    end

    # Year.
    year = params[:year].to_i
    matches = matches.where("tournaments.start LIKE '#{year}-%' OR tournaments.finish LIKE '#{year}-%'") if year > 0

    # Player.
    icu_id = params[:icu_id].to_i
    first_name = params[:first_name].strip if params[:first_name].present?
    last_name  = params[:last_name].strip  if params[:last_name].present?
    if icu_id > 0 || first_name || last_name
      matches = matches.includes(:players)  # the includes, rather than joins, prevents duplicate tournaments
      matches = matches.where("players.icu_id = ?", icu_id)                   if icu_id > 0
      matches = matches.where("players.first_name LIKE ?", "%#{first_name}%") if first_name
      matches = matches.where("players.last_name  LIKE ?", "%#{last_name}%")  if last_name
    end

    # FIDE rated.
    matches = matches.where("tournaments.fide_id IS NOT NULL") if params[:fide_rated] == "true"
    matches = matches.where("tournaments.fide_id IS NULL")     if params[:fide_rated] == "false"

    if params[:admin]
      # Reporter.
      user_id = params[:user_id].to_i
      matches = matches.where(user_id: user_id) if user_id > 0

      # Status.
      status = params[:status]
      matches = matches.where("tournaments.status  = 'ok'") if status == "ok"
      matches = matches.where("tournaments.status != 'ok'") if status == "problems"

      # Stage.
      stage = params[:stage]
      matches = matches.where(stage: stage) if stage.present?

      # Lock.
      locked = params[:locked]
      matches = matches.where(locked: true) if locked == "true"
      matches = matches.where(locked: false) if locked == "false"
    else
      # Only "ok" status.
      matches = matches.where(status: "ok")

      # Never "initial" stage.
      matches = matches.where("tournaments.stage != 'initial'")
    end

    paginate(matches, path, params)
  end

  # The latest tournaments for members and guests.
  def self.latest(limit=10)
    ordered.where(status: "ok").where("stage != 'initial'").limit(limit)
  end

  # The last tournament rated on or before a given date.
  def self.get_last_rated(date)
    where(stage: "rated").where("finish <= ?", date).order("rorder DESC").first
  end

  # Return an ICU::Tournament instance built from a database Tournament.
  def icu_tournament(opts={})
    icut = ICU::Tournament.new(name, start)
    %w[finish rounds fed city site arbiter deputy time_control].each do |attr|
      icut.send("#{attr}=", self.send(attr)) unless self.send(attr).blank?
    end
    icut.tie_breaks = tie_breaks.split(',') unless tie_breaks.blank?
    players.each do |p|
      opt = { id: p.icu_id, rating: p.icu_rating }
      [:fed, :fide_id, :fide_rating, :gender, :rank, :title, :dob].each { |attr| opt[attr] = p.send(attr) }
      icut.add_player(ICU::Player.new(p.first_name, p.last_name, p.id, opt))
    end
    players.each do |p|
      p.results.each do |r|
        opt = { opponent: r.opponent_id }
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
      icut = icu_tournament(renumber: order)
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
        r.update_column_if_changed(:opponent_id, map[r.opponent_id])
      end
    end
  end

  # Remove one player from the tournament.
  def remove(player)
    num = player.num
    rank = player.rank
    players.each do |p|
      p.update_column(:num, p.num - 1)   if p.num > num
      p.update_column(:rank, p.rank - 1) if rank && p.rank && p.rank > rank
    end
    player.destroy
  end

  # The players in rank order or, if the ranking is invalid, in name order.
  def ordered_players(opt={})
    if !opt[:by_name] && rankable
      players.sort { |a,b| a.rank <=> b.rank }
    else
      players.sort { |a,b| a.name <=> b.name }
    end
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

  # Return a hash describing the players' ranking numbers (e.g. if they're consistent or not).
  def ranking_summary
    r2s, min, max, dup = Hash.new, nil, nil, false
    # The minimum and maximum ranking numbers.
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
    # Turn the invalidity into a hash with various values including a string description.
    # Calling code should not rely on the description which is for the UI and may change.
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
      valid:       symbol == :valid,
      rankable:    symbol == :valid || symbol == :inconsistent,
      type:        symbol,
      description: string,
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
      player.update_column_if_changed(:rank, icup.rank)
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

  # Return the name with years. E.g. "Bunratty Masters 2012", "Armstrong League 2011-12".
  def name_with_year
    s = start.year.to_s
    return name if name.include?(s)
    f = finish.year.to_s if finish
    s << "-" + f[-2..-1] if f && f != s
    "#{name} #{s}"
  end

  # Return a summary of the orinial data.
  def original_data
    data = Array.new
    %w[name start finish tie_breaks].each do |key|
      val = self.send("original_#{key}")
      next if val.blank?
      val.gsub!(/,/, "|") if key == "tie_breaks"
      data.push val
    end
    data.join(", ")
  end

  # Can this tournament be deleted?
  def deletable?
    stage == "initial" || stage == "ready"
  end

  # What are all the stages that this tournament can move to?
  def move_stage_options(user)
    STAGE.inject([]) do |options, new_stage|
      can_move_to?(new_stage, user) ? options.push(new_stage) : options
    end
  end

  # Try to move the tourament from one stage to another.
  def move_stage(new_stage, user)
    # Check for basic errors.
    error = case
    when !STAGE.include?(new_stage)     then "is invalid"
    when !can_move_to?(new_stage, user) then "cannot move to this stage"
    end
    errors.add(:stage, error) and return if error

    # Take care of side effects.
    case
    when !rorder && new_stage == "queued" then queue
    when  rorder && new_stage == "ready"  then dequeue
    end

    # Finally, update the attribute.
    update_column(:stage, new_stage)
  end

  # Check if the current status has acceptable value.
  def status_ok?(recalculate=false)
    reset_status(recalculate)
    status == "ok"
  end

  # Recalculate and reset the status.
  def reset_status(recalculate=false)
    status = calculate_status(recalculate)
    update_column_if_changed(:status, status)
  end

  # What is the first tournament due for rating or re-rating? Note that queued and rated
  # tournaments should have order and ordered tournaments should either be queued or rated.
  def self.next_for_rating
    queued     = where(stage: "queued").order(:rorder).limit(1).first
    changed    = where(stage: "rated").where("last_signature != curr_signature").order(:rorder).limit(1).first
    moved      = where(stage: "rated").where("last_tournament_id != old_last_tournament_id").order(:rorder).limit(1).first
    rerateable = where(stage: "rated").where(rerate: true).order(:rorder).limit(1).first
    outofdate  = find_by_sql(first_outofdate_sql).first
    firsts     = [queued, changed, moved, rerateable, outofdate].reject! { |i| i.nil? }
    return nil if firsts.empty?
    firsts.sort{ |a,b| a.rorder <=> b.rorder }.first
  end

  # What is the first tournament that could be rating or re-rating?
  def self.first_for_rating
    min_rorder = Tournament.minimum(:rorder)
    Tournament.where(rorder: min_rorder).first if min_rorder
  end

  # What is the last tournament that could be rating or re-rating?
  def self.last_for_rating
    max_rorder = Tournament.maximum(:rorder)
    Tournament.where(rorder: max_rorder).first if max_rorder
  end

  def self.first_outofdate_sql
    <<-'HERE'
    SELECT t2.*
    FROM tournaments t1, tournaments t2
    WHERE t1.rorder + 1 = t2.rorder AND (t1.last_rated > t2.last_rated OR (t1.last_rated = t2.last_rated AND t1.last_rated_msec > t2.last_rated_msec))
    ORDER BY t2.rorder
    LIMIT 1
    HERE
  end

  # Rate this tournament. Returning an error message or nil.
  def rate
    rate!
    update_live_ratings
    nil
  rescue => e
    Failure.record(e, 16) unless e.instance_of?(ICU::Error)
    e.message
  end

  # Rate this tournament. Return nil or throw an exception.
  def rate!
    check_rateable
    transaction do
      get_old_ratings
      get_k_factors
      icut = calculate_ratings
      update_player_ratings(icut)
      update_tournament_after_rating
    end
  end

  # Check for any changes before Tournament#show.
  def check_for_changes
    reset_status
    reset_signatures(false)
  end

  # As far as possible, prepare the tournament for FIDE submission. In other words,
  # use ICU IDs to map to FIDE IDs, or at least to fedeartions and DOBs. Return an
  # array of comments to give feedback to the user.
  def update_fide_data
    comments = {}

    # We need players with ICU IDs.
    with_icu_id = players.select{ |p| p.icu_id }.count
    comments.store(:with_icu_id, with_icu_id == 0 ? "None" : with_icu_id)
    return comments unless with_icu_id > 0

    # Initialise the lists we'll return (note translations for each of these in tournaments.yml).
    %w{
      fid_new fid_changed fid_unchanged fid_unrecognized
      fed_new fed_changed fed_unchanged fed_unrecognized fed_mismatch
      dob_new dob_changed dob_unchanged dob_unrecognized dob_mismatch dob_removed
    }.each { |c| comments[c.to_sym] = [] }

    # Loop over the players.
    players.select{ |p| p.icu_id }.each do |player|
      icu_player = player.icu_player
      next unless icu_player

      # FIDE ID. Always set this if we can find it.
      fide_player = icu_player.fide_player
      id = fide_player.id if fide_player
      if id
        if player.fide_id
          if player.fide_id == id
            comments[:fid_unchanged].push player
          else
            player.update_column(:fide_id, id)
            comments[:fid_changed].push player
          end
        else
          player.update_column(:fide_id, id)
          comments[:fid_new].push player
        end
      elsif player.fide_id
        comments[:fid_unrecognized].push player
      end

      # Federation. Always set this if we can find it.
      fed = icu_player.fed
      if fed
        if fide_player && fide_player.fed && fide_player.fed != fed
          comments[:fed_mismatch].push player
        else
          if player.fed
            if player.fed == fed
              comments[:fed_unchanged].push player
            else
              player.update_column(:fed, fed)
              comments[:fed_changed].push player
            end
          else
            player.update_column(:fed, fed)
            comments[:fed_new].push player
          end
        end
      elsif player.fed
        comments[:fed_unrecognized].push player
      end

      # DOB. Set this if we don't have an ID, otherwise prefer to omitt it.
      dob = icu_player.dob
      if fide_player
        if fide_player.born && fide_player.born != dob.year
          comments[:dob_mismatch].push player
        end
        if player.dob
          player.update_column(:dob, nil)
          comments[:dob_removed].push player
        end
      elsif dob
        if player.dob
          if player.dob == dob
            comments[:dob_unchanged].push player
          else
            player.update_column(:dob, dob)
            comments[:dob_changed].push player
          end
        else
          player.update_column(:dob, dob)
          comments[:dob_new].push player
        end
      elsif player.dob
        comments[:dob_unrecognized].push player
      end
    end

    # Return the final comments hash.
    comments
  end

  def notes_snippet
    return unless notes.present?
    snippet = notes
    snippet.gsub!(/[^\w\s]/i, '')
    snippet.gsub!(/\s+/, " ")
    snippet = snippet[0,29] + "..." if snippet.length > 32
    snippet
  end

  def fide_url
    return nil unless fide_id
    "http://ratings.fide.com/tournament_details.phtml?event=#{fide_id}"
  end

  private

  def finish_on_or_after_start
    errors.add(:finish, "- end date can't be before start date") if finish && finish < start
  end

  def normalise_attributes
    %w[start finish fed city site arbiter deputy time_control tie_breaks].each do |attr|
      self.send("#{attr}=", nil) if self.send(attr).to_s.match(/^\s*$/)
    end
  end

  # Guess a finish if there isn't one already.
  def guess_finish
    return if finish
    return unless start && rounds
    length = case rounds
    when 1,2,3 then 1
    when 4,5,6 then 3
    else rounds
    end
    self.finish = start + (length - 1).days
  end

  # Translate from CGI params to export options.
  def export_params(params)
    format = %w[Krause SPExport ForeignCSV].find { |f| f == params[:type] } || 'Krause'
    order = %w[rank name].find { |o| o == params[:order] }
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

  def calculate_status(recalculate)
    errors = Array.new
    check_player_count(errors)
    check_player_status(errors, recalculate)
    check_player_category(errors)
    return "ok" if errors.empty?
    errors.join("|")
  end

  def check_player_count(errors)
    return if players.count > 1
    errors.push("a minimum of 2 players are required")
  end

  def check_player_status(errors, recalculate)
    bad = players.reject { |p| p.status_ok?(recalculate) }
    return if bad.size == 0
    clue = bad[0].name(false)
    clue << ", #{bad[1].name(false)}" if bad.size > 1
    clue << ", ..." if bad.size > 2
    errors.push("#{bad.size} player#{bad.size == 1 ? '' : 's'} (#{clue}) #{bad.size == 1 ? 'has' : 'have'} a bad status")
  end

  def check_player_category(errors)
    return if 0 < players.inject(0) { |m, p| m += 1 if p.category == "icu_player"; m }
    errors.push("at least 1 ICU player is required")
  end

  # Can this tournament be moved to a given stage from the one it's currently at?
  def can_move_to?(new_stage, user)
    return false unless user
    case new_stage.to_s
    when "initial" then stage == "ready"
    when "queued"  then stage.match(/^ready|rated/) && user.role?(:officer)
    when "ready"   then stage.match(/^queued|rated$/) && user.role?(:officer) || stage == "initial" && status_ok?
    else false
    end
  end

  # Is the tournament stage suitable for rating (or rerating).
  def rateable?
    stage == "queued" || stage == "rated"
  end

  # Queue a tournament for rating (establish it's order in the list of tournaments).
  def queue
    rorder = queue_position
    Tournament.where("rorder >= ?", rorder).order("rorder DESC").each { |t| t.update_column(:rorder, t.rorder + 1) }
    update_column(:rorder, rorder)
    a, b = calc_last_tournament, calc_next_tournament
    update_column(:last_tournament_id, a.try(:id))
    a.update_column(:next_tournament_id, id) if a
    update_column(:next_tournament_id, b.try(:id))
    b.update_column(:last_tournament_id, id) if b
  end

  # Unqueue a tournament for rating (blank it's order to remove it from the list of tournaments).
  def dequeue
    a, b = last_tournament, next_tournament
    rorder = self.rorder
    [:rorder, :last_tournament_id, :next_tournament_id].each { |col| update_column(col, nil) }
    Tournament.where("rorder > ?", rorder).order(:rorder).each { |t| t.update_column(:rorder, t.rorder - 1) }
    a.update_column(:next_tournament_id, b.try(:id)) if a
    b.update_column(:last_tournament_id, a.try(:id)) if b
  end

  # Requeue a queued or rated tournament in mid_edit (i.e. in a callback) if any of the changes could affect it's queue position, assuming it has one.
  # In between dequeue and queue the tournament will have an inconsistent state (stage is "rated" or "queued" but no rorder) but only temporarily.
  def requeue
    return unless self.rorder
    return if rorder_changed?
    return unless finish_changed? || start_changed? || name_changed? || rounds_changed?
    a, b = last_tournament, next_tournament
    return unless (a && !queue_position_higher(a)) || (b && queue_position_higher(b))
    dequeue
    queue
  end

  # Find the right queue position.
  def queue_position
    count = Tournament.where("rorder IS NOT NULL").count
    return 1 if count == 0
    t = Tournament.where(rorder: count).first
    raise ICU::Error, "queue_position: expected tournament with order #{count}" unless t
    return count + 1 if queue_position_higher(t)
    queue_position_finder(1, count)
  end

  # Binary search to recursively find queue position. Invariants: p2 >= p1 and solution is not higher than p2.
  def queue_position_finder(p1, p2)
    raise ICU::Error, "queue_position_finder: bad invariant (#{p1}, #{p2})" unless p2 >= p1
    return p2 if p1 == p2  # because solution is never higher than p2
    m = ((p1 + p2) / 2.0).floor
    raise ICU::Error, "queue_position_finder: expected mid-point (#{m}) to be less than last point (#{p2})" unless p2 > m
    t = Tournament.where(rorder: m).first
    raise ICU::Error, "queue_position_finder: expected tournament with rorder #{m}" unless t
    queue_position_higher(t) ? queue_position_finder(m + 1, p2) : queue_position_finder(p1, m)
  end

  # Compare this tournament to another and return true if it should be higher in the queue and false otherwise.
  def queue_position_higher(t)
    return finish > t.finish if finish != t.finish
    return start  > t.start  if start  != t.start
    return rounds > t.rounds if rounds != rounds
    return name   > t.name   if name   != t.name
    id > t.id  # tie breaker
  end

  # Calculate the next queued or rated tournament after this one (see queue and dequeue).
  def calc_next_tournament
    return if !rorder || rorder >= Tournament.where("rorder IS NOT NULL").count
    Tournament.where(rorder: rorder + 1).first
  end

  # Calculate the previous queued or rated tournament before this one (see queue and dequeue).
  def calc_last_tournament
    return if !rorder || rorder <= 1
    Tournament.where(rorder: rorder - 1).first
  end

  # Check a tournament is ready to be rated.
  def check_rateable
    raise ICU::Error, "tournament stage (#{stage}) is not suitable for rating" unless rateable?
    raise ICU::Error, "tournament status (#{status}) is not suitable for rating" unless status_ok?(true)
  end

  # Get the start ratings of all players.
  def get_old_ratings
    icu_ids = players.select{ |p| p.category == "icu_player" }.map(&:icu_id)
    latest = Player.get_last_ratings(icu_ids, rorder)
    legacy = OldRating.get_ratings(icu_ids)
    players.each { |p| p.get_old_rating(latest, legacy) }
  end

  # Set k-factors for ICU players.
  def get_k_factors
    players.each { |p| p.get_k_factor(start) }
  end

  # Add players and results to an ICU::RatedTournament instance and rate it.
  def calculate_ratings
    t = ICU::RatedTournament.new(desc: "Scratch")
    players.each { |p| p.add_player t }
    players.each { |p| p.add_results t }
    t.rate!(version: 3)
    self.iterations1 = t.iterations1
    self.iterations2 = t.iterations2
    self.save
    t
  end

  # Get player ratings from and ICU::RatedTournament after a successful rating calculation.
  def update_player_ratings(t)
    players.each { |p| p.get_ratings t.player(p.id) }
  end

  # Update tournament data after a successful rating calculation.
  def update_tournament_after_rating
    now = Time.now
    msec = ((now.to_f - now.to_i) * 1000).to_i
    update_column(:first_rated, now) unless first_rated
    update_column(:last_rated, now)
    update_column(:last_rated_msec, msec)
    update_column(:reratings, reratings + 1)
    update_column(:rerate, false)
    update_column_if_changed(:stage, "rated")
    update_column_if_changed(:old_last_tournament_id, last_tournament_id)
    update_column_if_changed(:locked, true)
    reset_signatures(true)
  end
  
  # Update live ratings if appropriate.
  def update_live_ratings
    return unless last_rated?
    LiveRating.recalculate
  end

  # Is this the last rated tournament?
  def last_rated?
    return false unless stage == "rated" && rorder
    Tournament.where("rorder > #{rorder}").count == 0
  end

  # Set the last and current signatures for the tournament and each player after the tournament has been rated,
  # or just reset the current signatures so we can detect when the tournament has changed and needs re-rating.
  def reset_signatures(set_last)
    return unless stage == "rated"
    players_signature = ""
    players.sort{ |a,b| a.id <=> b.id }.each do |p|
      signature = p.signature
      p.update_column_if_changed(:curr_signature, signature)
      p.update_column_if_changed(:last_signature, signature) if set_last
      players_signature << signature
    end
    players_signature = Digest::MD5.hexdigest(players_signature)
    update_column_if_changed(:curr_signature, players_signature)
    update_column_if_changed(:last_signature, players_signature) if set_last
  end
end
