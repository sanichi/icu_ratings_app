# == Schema Information
#
# Table name: players
#
#  id                   :integer(4)      not null, primary key
#  first_name           :string(255)
#  last_name            :string(255)
#  fed                  :string(3)
#  title                :string(3)
#  gender               :string(1)
#  icu_id               :integer(4)
#  fide_id              :integer(4)
#  icu_rating           :integer(2)
#  fide_rating          :integer(2)
#  dob                  :date
#  status               :string(255)
#  category             :string(255)
#  rank                 :integer(2)
#  num                  :integer(4)
#  tournament_id        :integer(4)
#  original_name        :string(255)
#  original_fed         :string(3)
#  original_title       :string(3)
#  original_gender      :string(1)
#  original_icu_id      :integer(4)
#  original_fide_id     :integer(4)
#  original_icu_rating  :integer(2)
#  original_fide_rating :integer(2)
#  original_dob         :date
#  created_at           :datetime
#  updated_at           :datetime
#  old_rating           :integer(2)
#  new_rating           :integer(2)
#  trn_rating           :integer(2)
#  old_games            :integer(2)
#  new_games            :integer(2)
#  bonus                :integer(2)
#  k_factor             :integer(1)
#  last_player_id       :integer(4)
#  actual_score         :decimal(3, 1)
#  expected_score       :decimal(8, 6)
#  last_signature       :string(255)
#  curr_signature       :string(255)
#  old_full             :boolean(1)      default(FALSE)
#  new_full             :boolean(1)      default(FALSE)
#  unrateable           :boolean(1)      default(FALSE)
#  rating_change        :integer(2)      default(0)
#

require "icu/error"

class Player < ActiveRecord::Base
  extend ICU::Util::Pagination

  FEDS = ICU::Federation.codes
  TITLES = %w[GM IM FM CM NM WGM WIM WFM WCM WNM]
  GENDERS = %w[M F]
  CATEGORY = %w[icu_player foreign_player new_player]

  belongs_to :tournament, include: :players
  belongs_to :last_player, class_name: "Player"
  belongs_to :icu_player, foreign_key: "icu_id"
  belongs_to :fide_player, foreign_key: "fide_id"
  has_many :results, dependent: :destroy

  attr_accessible :first_name, :last_name, :icu_id, :fide_id, :fed, :title, :gender, :dob, :icu_rating, :fide_rating

  before_validation :normalise_attributes, :canonicalize_names, :deduce_category_and_status

  validates_presence_of     :first_name, :last_name, :original_name
  validates_numericality_of :icu_id, :original_icu_id, only_integer: true, greater_than: 0, allow_nil: true
  validates_numericality_of :fide_id, :original_fide_id, only_integer: true, greater_than: 0, allow_nil: true
  validates_inclusion_of    :fed, :original_fed, in: FEDS, allow_nil: true, message: "(%{value}) is invalid"
  validates_inclusion_of    :title, :original_title, in: TITLES, allow_nil: true, message: "(%{value}) is invalid"
  validates_inclusion_of    :gender, :original_gender, in: GENDERS, allow_nil: true, message: "(%{value}) should be #{GENDERS.join(' or ')}"
  validates_date            :dob, :original_dob, after: "1910-01-01", on_or_before: :today, allow_nil: true
  validates_numericality_of :icu_rating, :original_icu_rating, :fide_rating, :original_fide_rating, only_integer: true, greater_than: 0, allow_nil: true
  validates_numericality_of :rank, only_integer: true, greater_than: 0, allow_nil: true
  validates_numericality_of :num, only_integer: true, greater_than: 0
  validates_inclusion_of    :category, in: CATEGORY, allow_nil: true, message: "(%{value}) is invalid"
  validates_presence_of     :status

  def self.build_from_icut(icup, tournament)
    # Build basic player from an attribute hash (these must be unprotected attributes).
    attrs = {}
    %w[first_name last_name fide_id fed title gender dob fide_rating].each do |key|
      attrs[key.to_sym] = icup.send(key) unless icup.send(key).blank?
    end
    attrs[:icu_id] = icup.id unless icup.id.blank?
    attrs[:icu_rating] = icup.rating unless icup.rating.blank?
    player = tournament.players.build(attrs)

    # Set protected (by attr_accessible or attr_protected) attributes.
    player.num = icup.num
    player.rank = icup.rank unless icup.rank.blank?

    # Set original data (also protected as it should never change).
    player.original_name = icup.original_name
    player.original_icu_id = icup.id unless icup.id.blank?
    player.original_icu_rating = icup.rating unless icup.rating.blank?
    %w[fide_id fed title gender dob fide_rating].each do |key|
      player.send("original_#{key}=", icup.send(key)) unless icup.send(key).blank?
    end

    # Results.
    icup.results.each do |icur|
      Result.build_from_icut(icur, player)
    end
  end

  def name(last_first=true)
    last_first ? "#{last_name}, #{first_name}" : "#{first_name} #{last_name}"
  end

  def status_ok?(recalculate=false)
    deduce_category_and_status if recalculate
    status == "ok"
  end

  def score
    results.inject(0.0) { |s,r| s+= r.score }
  end

  def result_in_round(n)
    results.detect{ |r| r.round == n }
  end

  def original_data
    data = Array.new
    %w[name icu_id fide_id fed title gender dob icu_rating fide_rating].each do |key|
      val = self.send("original_#{key}")
      data.push val if val.present?
    end
    data.join(", ")
  end

  def changed_from_original?(opt={})
    keys = %w[name icu_id fide_id fed title gender dob icu_rating fide_rating]
    case
    when opt[:only]
      only = opt[:only].instance_of?(Array) ? opt[:only].map(&:to_s) : [opt[:only].to_s]
      keys = keys & only
    when opt[:except]
      expt = opt[:except].instance_of?(Array) ? opt[:except].map(&:to_s) : [opt[:except].to_s]
      keys = keys - expt
    end
    keys.each do |key|
      case key
      when "name"
        return true if original_name != name && original_name != name(false)
      else
        return true if self.send(key) != self.send("original_#{key}")
      end
    end
    false
  end

  # Get the old rating, games and full/prov for one player in a tournament.
  def get_old_rating(latest_ratings, legacy_ratings)
    case category
    when "icu_player"
      if latest = latest_ratings[icu_id]
        update_column_if_changed(:old_rating, latest.new_rating)
        update_column_if_changed(:old_games, latest.new_games)
        update_column_if_changed(:old_full, latest.new_full)
      elsif legacy = legacy_ratings[icu_id]
        update_column_if_changed(:old_rating, legacy.rating)
        update_column_if_changed(:old_games, legacy.games)
        update_column_if_changed(:old_full, legacy.full)
      else
        update_column_if_changed(:old_rating, nil)
        update_column_if_changed(:old_games, 0)
        update_column_if_changed(:old_full, false)
      end
    when "new_player"
      update_column_if_changed(:old_rating, nil)
      update_column_if_changed(:old_games, 0)
      update_column_if_changed(:old_full, false)
    when "foreign_player"
      update_column_if_changed(:old_rating, fide_rating)
      update_column_if_changed(:old_games, 0)
      update_column_if_changed(:old_full, false)
    else
      raise ICU::Error, "player #{id} (#{name}) has " + (category ? "invalid category (#{category})" : "no category")
    end
    update_column_if_changed(:last_player_id, latest ? latest.id : nil)
  end

  # Get a player's rating from his last rated tournament. No longer used, as get_player_ratings is faster.
  def self.get_last_rating(icu_id, rorder)
    match = joins(:tournament)
    match = match.where("tournaments.stage = 'rated'")
    match = match.where("tournaments.rorder < #{rorder}")
    match = match.where(icu_id: icu_id)
    match = match.order("tournaments.rorder")
    match.last
  end

  # Get multiple players from their last rated tournaments prior to a given rating order number.
  # Return as a hash from icu_id number to Player instance. For more ideas on how to do this, see
  # http://stackoverflow.com/questions/121387/fetch-the-row-which-has-the-max-value-for-a-column.
  def self.get_last_ratings(icu_ids, rorder)
    sql = <<SQL
SELECT
  p.*
FROM
  tournaments t,
  players p,
  (
    SELECT
      max(t.rorder) rorder,
      p.icu_id icu_id
    FROM
      players p,
      tournaments t
    WHERE
      p.icu_id IN (#{icu_ids.join(',')}) AND
      p.tournament_id = t.id AND
      t.stage = "rated" AND
      t.rorder < #{rorder}
    GROUP BY
      p.icu_id
  ) x
WHERE
  t.id = p.tournament_id AND
  t.rorder = x.rorder AND
  p.icu_id = x.icu_id
SQL
    find_by_sql(sql).inject({}){ |h, p| h[p.icu_id] = p; h }
  end

  # Get a player's most recent tournaments or their biggest gains or losses.
  def self.get_players(icu_id, type, limit)
    match = joins(:tournament).includes(:tournament)
    match = match.where(icu_id: icu_id)
    match = match.where(tournaments: { stage: "rated" })
    case type
    when :gain
      match = match.where("rating_change > 0")
      match = match.where("old_rating IS NOT NULL")
      match = match.order("rating_change DESC")
    when :loss
      match = match.where("rating_change < 0")
      match = match.where("old_rating IS NOT NULL")
      match = match.order("rating_change ASC")
    end
    match = match.order("tournaments.rorder DESC")
    match.limit(limit)
  end

  # Search for players and return paginated results.
  def self.search(params, path)
    matches = joins(:tournament).includes(:tournament)
    matches = matches.where(icu_id: params[:icu_id].to_i)  # normally icu_id will be set, but, if not, both nil and non-integers maps to 0
    matches = matches.where(tournaments: { stage: "rated" })
    matches = matches.order("tournaments.rorder DESC")
    paginate(matches, path, params)
  end

  # Search for new players and return paginated results.
  def self.search_new_players(params, path)
    matches = joins(:tournament).includes(:tournament)
    matches = matches.where(tournaments: { stage: "rated" })
    matches = matches.where(category: "new_player")
    matches = matches.where("last_name LIKE ?", "%#{params[:last_name]}%") if params[:last_name].present?
    matches = matches.where("first_name LIKE ?", "%#{params[:first_name]}%") if params[:first_name].present?
    matches = matches.order("last_name ASC, first_name ASC, tournaments.name DESC")
    paginate(matches, path, params)
  end

  # Set the k-factor for an ICU player with a full rating (is called after get_old_ratings).
  def get_k_factor(start)
    return unless category == "icu_player" && old_full
    args = { start: start, rating: old_rating }
    args[:dob]    = icu_player.dob    || "1950-01-01"
    args[:joined] = icu_player.joined || "1975-01-01"
    update_column_if_changed(:k_factor, ICU::RatedPlayer.kfactor(args))
  end

  # Add this player to an ICU::RatedTournament.
  def add_player(t)
    case category
    when "icu_player"
      case icu_player_type
      when "full_rating"        then t.add_player(id, rating: old_rating, kfactor: k_factor)
      when "provisional_rating" then t.add_player(id, rating: old_rating, games: old_games)
      when "first_tournament"   then t.add_player(id)
      else raise ICU::Error, "can't add ICU player #{id} (#{name}) for rating calculation"
      end
    when "new_player"           then t.add_player(id)
    when "foreign_player"       then t.add_player(id, rating: old_rating)
    else raise ICU::Error, "player #{id} (#{p.name}) has " + (category ? "invalid category (#{category})" : "no category")
    end
  end

  # Add this player's results to an ICU::RatedTournament. The player is assumed to be already added.
  def add_results(t)
    results.each do |r|
      t.add_result(r.round, r.player_id, r.opponent_id, r.result) if r.rateable
    end
  end

  # Extract this player's rating calculations from an ICU::RatedPlayer.
  def get_ratings(p)
    count = p.results.size
    if count > 0 && p.new_rating
      update_column_if_changed(:unrateable, false)
      case category
      when "icu_player", "new_player"
        new_games = old_games + count
        new_rating = p.new_rating.round
        rating_change = old_rating ? new_rating - old_rating : 0
        update_column_if_changed(:new_rating, new_rating)
        update_column_if_changed(:new_games, new_games)
        update_column_if_changed(:new_full, old_full || new_games >= 20)
        update_column_if_changed(:trn_rating, p.performance.round)
        update_column_if_changed(:rating_change, rating_change)
        update_column_if_changed(:actual_score, p.score)
        update_column_if_changed(:expected_score, p.expected_score)
      when "foreign_player"
        update_column_if_changed(:new_rating, old_rating)
        update_column_if_changed(:new_games, old_games)
        update_column_if_changed(:new_full, false)
        update_column_if_changed(:trn_rating, p.performance.round)
        update_column_if_changed(:rating_change, 0)
        update_column_if_changed(:actual_score, p.score)
        update_column_if_changed(:expected_score, p.expected_score)
      end
    else
      update_column_if_changed(:unrateable, count > 0)
      update_column_if_changed(:new_rating, old_rating)
      update_column_if_changed(:new_games, old_games)
      update_column_if_changed(:new_full, old_full)
      update_column_if_changed(:rating_change, 0)
      [:trn_rating, :bonus, :actual_score, :expected_score].each do |a|
        update_column_if_changed(a, nil)
      end
    end
    if count > 0 && category == "icu_player" && icu_player_type == "full_rating"
      update_column_if_changed(:bonus, p.bonus)
      update_column_if_changed(:pre_bonus_rating, p.pb_rating)
      update_column_if_changed(:pre_bonus_performance, p.pb_performance)
    else
      update_column_if_changed(:bonus, nil)
      update_column_if_changed(:pre_bonus_rating, nil)
      update_column_if_changed(:pre_bonus_performance, nil)      
    end
    results.each do |r|
      pr = p.results.find { |s| s.round == r.round }
      if pr
        r.update_column_if_changed(:expected_score, pr.expected_score)
        r.update_column_if_changed(:rating_change, pr.rating_change)
      else
        r.update_column_if_changed(:expected_score, nil)
        r.update_column_if_changed(:rating_change, nil)
      end
    end
  end

  # Calculate a signature for detecting changes to rating data.
  def signature
    sig = []
    sig.push icu_id if category == "icu_player"
    sig.push fide_rating if category == "foreign_player"
    sig.push results.find_all{ |r| r.rateable }.map(&:signature).join(" ")
    sig.find_all{ |x| x.present? }.join(" ")
  end

  # Given it's an ICU player, what sub-category is it?
  def icu_player_type
    @icu_player_type ||= case
    when old_rating && old_full  then "full_rating"
    when old_rating && old_games then "provisional_rating"
    when !old_rating             then "first_tournament"
    else "undefined"
    end
  end

  # The rating used for this player when calculating ratings of the opponents.
  # The tournament must be rated first to give a meaningful answer.
  def start_rating
    @start_rating ||= category == "icu_player" && icu_player_type == "full_rating" && bonus == 0 ? old_rating : new_rating
  end

  # The average of the opponents' start ratings.
  # The tournament must be rated first to give a meaningful answer.
  def ave_opp_rating
    return @ave_opp_rating if @ave_opp_rating
    ave = 0.0
    num = 0
    results.each do |r|
      if r.rateable
        num+= 1
        ave+= r.opponent.start_rating || 0.0
      end
    end
    @ave_opp_rating = num == 0 ? ave : ave / num
  end

  # Total number of games with opponents (including unrateable).
  def opponents
    @opponents ||= results.to_a.count{ |r| r.opponent }
  end

  # Is a player deletable?
  def deletable?
    opponents == 0
  end

  # Total number of rateable games.
  def rateable_games
    @rateable_games ||= results.to_a.count{ |r| r.rateable }
  end

  # The total score in rateable games.
  def rateable_score
    @rateable_score ||= results.inject(0.0) { |t, r| t + (r.rateable ? r.score : 0.0) }
  end

  # A player's performance rating. For provisional players, ICU::RatedPlayer.trn_rating
  # only reports the weighted average with the last rating so we need an independendent
  # way to get it.
  def performance_rating
    @performance_rating ||= rateable_games == 0 ? 0.0 : (ave_opp_rating + 400.0 * (2.0 * rateable_score - rateable_games) / rateable_games)
  end

  # The same ICU player in their next rated tournament (always calculated as opposed to last_player_id which is set during rating).
  # We make use of the fact that there should be at most one other player which points back to this player.
  def next_player
    @next_player ||= Player.where(last_player_id: id).joins(:tournament).where("tournaments.stage = 'rated'").first
  end

  private

  # Correlated with the Help text in admin/players/show.
  def deduce_category_and_status
    errors = Array.new
    category = nil

    # Check for ICU and FIDE errors.
    match_icu(errors)
    match_fide(errors)

    # Determine category, if there are no errors.
    if errors.empty?
      case
      when icu_id.present?
        category = "icu_player"
      when fide_rating.present? && fed.present?
        category = "foreign_player"
      when icu_id.blank? && icu_rating.blank? && fide_rating.blank?
        category = "new_player"
      else
        errors.push "cannot determine category"
      end
    end

    if errors.empty?
      self.status   = "ok"
      self.category = category
    else
      self.status   = errors.join("|")
      self.category = nil
    end
  end

  def match_icu(errors)
    return if icu_id.blank?
    if icu_player
      cname = ICU::Name.new(icu_player.first_name, icu_player.last_name)
      unless cname.match(first_name, last_name)
        errors.push "ICU name mismatch: #{icu_player.name}"
      end
      if icu_player.master_id
        errors.push("Match with duplicate ICU player")
      else
        %w[dob fed gender].each do |attr|
          a = icu_player.send(attr).presence || next
          b = self.send(attr).presence || next
          unless a == b
            errors.push("ICU #{attr} mismatch: #{a}")
          end
        end
      end
    else
      errors.push "#{icu_id}: no such ICU player"
    end
  end

  def match_fide(errors)
    return if fide_id.blank?
    if fide_player
      cname = ICU::Name.new(fide_player.first_name, fide_player.last_name)
      unless cname.match(first_name, last_name)
        errors.push "FIDE name mismatch: #{fide_player.name}"
      end
      %w[fed gender].each do |attr|
        a = fide_player.send(attr).presence || next
        b = self.send(attr).presence || next
        unless a == b
          errors.push("FIDE #{attr} mismatch: #{fide_player.send(attr)}") unless fide_player.send(attr) == self.send(attr)
        end
      end
      if fide_player.born.present? && self.dob.present?
        unless fide_player.born == self.dob.year
          errors.push("FIDE year of birth mismatch: #{fide_player.born}")
        end
      end
    else
      # Disable this check as our database of FIDE players is incomplete.
      # errors.push "#{fide_id}: no such FIDE player"
    end
  end

  def normalise_attributes
    %w[fed title gender dob].each do |attr|
      self.send("#{attr}=", nil) if self.send(attr).to_s.match(/^\s*$/)
    end
  end

  def canonicalize_names
    name = ICU::Name.new(first_name, last_name)
    self.first_name = name.first(chars: "US-ASCII")
    self.last_name = name.last(chars: "US-ASCII")
  end
end
