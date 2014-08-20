# == Schema Information
#
# Table name: rating_lists
#
#  id                    :integer(4)      not null, primary key
#  date                  :date
#  tournament_cut_off    :date
#  payment_cut_off       :date
#  created_at            :datetime
#  updated_at            :datetime
#

class RatingList < ActiveRecord::Base
  extend ICU::Util::Pagination

  has_many :publications, dependent: :destroy

  validates :date, date: { on_or_after: "2012-01-01", on_or_before: :today }
  validates :date, list_date: true
  validates :tournament_cut_off, :payment_cut_off, date: true
  validate  :cut_off_rules

  default_scope -> { order(date: :desc) }

  def publish(today = Date.today)
    @stats = Publication::STATS.inject({}) { |h, k| h[k] = 0; h }
    @stats[:report] = "Starting publication of #{date.strftime('%Y %b')} list at #{Time.now.to_s(:dbm)}\n"

    begin
      @first = first_publication?
      @originals = set_original_ratings?(today)
      @current = get_current_ratings

      if @first
        if @current.size > 0
          pass_preloaded_list
        else
          publish_list
        end
      else
        publish_list
      end
    rescue => e
      return e.message
    end

    # Create the new publication and signal all is OK.
    publications.create!(@stats)
    false
  end

  def self.auto_populate
    have = all.inject({}) { |h, l| h[l.date] = true; h }
    date = Date.new(2012, 1, 1)  # first list of the new rating system
    high = Date.today
    todo = []
    while date <= high
      todo.push(date) unless have[date]
      date = date >> 4
    end
    todo.each { |date| create(date: date, tournament_cut_off: date.change(day: 15), payment_cut_off: date.end_of_month) }
  end

  def self.search(params, path)
    matches = all
    matches = matches.where("date LIKE '#{params[:year]}%'") if params[:year].present?
    paginate(matches, path, params)
  end

  def next_list
    RatingList.unscoped.where("date > ?", date).order(date: :asc).limit(1).first
  end

  def prev_list
    RatingList.unscoped.where("date < ?", date).order(date: :desc).limit(1).first
  end

  def self.last_list
    unscoped.order(date: :desc).first
  end

  def last_list?
    RatingList.last_list.id == id
  end

  private

  def publish_list
    subs = get_subscriptions
    icu_ids = subs.keys
    rorder = get_last_tournament + 1
    tournament_ratings = get_tournament_ratings(rorder, icu_ids)
    legacy_ratings = get_legacy_ratings(icu_ids)
    t1 = Time.now
    report_header "Starting rating updates at #{t1.to_s(:tbm)}"

    legacy, tournaments = 0, 0
    changes = Hash.new { |h, k| h[k] = [] }
    no_rating, creates, remains, updates, deletes_no_rat, deletes_no_sub = [], [], [], [], [], []
    icu_ids.each do |icu_id|
      rating, full = nil, nil
      if latest = tournament_ratings[icu_id]
        rating = latest.new_rating
        full = latest.new_full
        tournaments += 1
      elsif old = legacy_ratings[icu_id]
        rating = old.rating
        full = old.full
        legacy += 1
      end

      rating = 700 if rating && rating < 700

      current = @current[icu_id]
      case
      when current && rating
        if current.rating == rating && current.full == full
          remains.push icu_id
        else
          add_to_changes(changes, current.rating, rating, icu_id)
          current.rating = rating
          current.full = full
          if @originals
            current.original_rating = rating
            current.original_full = full
          end
          current.save!
          updates.push icu_id
        end
      when current && !rating
        current.destroy
        deletes_no_rat.push icu_id
      when !current && rating
        hash = { list: date, icu_id: icu_id, rating: rating, full: full }
        hash[:original_rating] = @originals ? rating : nil
        hash[:original_full] = @originals ? full : nil
        IcuRating.create!(hash)
        creates.push icu_id
      when
        !current && !rating
        no_rating.push icu_id
      end

      @current.delete(icu_id) if current
    end
    report_item "tournament ratings used: #{tournaments}"
    report_item "legacy ratings used: #{legacy}"
    report_examples(no_rating, "subscribed members with no rating")

    @current.each_pair do |icu_id, rating|
      rating.destroy
      deletes_no_sub.push icu_id
    end

    t2 = Time.now
    report_item "finished rating updates at #{t2.to_s(:tbm)} (#{((t2 - t1) * 1000.0).round} ms)"

    @stats[:creates] = creates.size
    @stats[:remains] = remains.size
    @stats[:updates] = updates.size
    @stats[:deletes] = deletes_no_rat.size + deletes_no_sub.size
    @stats[:total] = @stats[:creates] + @stats[:remains] + @stats[:updates]

    report_header "Statistics"
    report_item "total: #{@stats[:total]}"
    report_examples(creates, "created")
    report_examples(remains, "unchanged")
    report_examples(updates, "changed")
    report_examples(deletes_no_rat, "deleted (no rating)")
    report_examples(deletes_no_sub, "deleted (no subscription)")
    unless changes.empty?
      report_header "Change statistics"
      changes.keys.sort.each { |bucket| report_examples(changes[bucket], bucket) }
    end
    
    if last_list?
      t3 = Time.now      
      report_header "Starting live rating recalculation at #{t1.to_s(:tbm)}"
      count = LiveRating.recalculate
      t4 = Time.now
      report_item "recalculated #{count} live ratings in #{((t4 - t3) * 1000.0).round} ms"
    end
  end

  def add_to_changes(hash, old_rating, new_rating, icu_id)
    diff = new_rating - old_rating
    direction = diff < 0 ? "decrease" : "increase"
    diff = (diff.abs / 10.0).ceil * 10
    if diff == 0
      bucket = "no change"
    elsif diff > 100
      bucket = "#{direction} > 100"
    else
      bucket = "#{direction} of #{diff-9}-#{diff}"
    end
    hash[bucket].push(icu_id)
  end

  def pass_preloaded_list
    report_header "Detected pre-loaded ratings"
    @stats[:total] = @current.size;
    @stats[:remains] = @current.size;
    report_item "these will be used (unchanged) as the first publication"
  end

  def first_publication?
    previous = publications.count
    report_item "previous publications of this list: #{previous}"
    previous == 0
  end

  def set_original_ratings?(today)
    set = today <= date || (today.year == date.year && today.month == date.month)
    report_item "original ratings will be #{set ? 'reset' : 'preserved'}"
    set
  end

  def get_current_ratings
    ratings = IcuRating.unscoped.where(list: date).to_a
    report_item "existing ratings: #{ratings.size}"
    ratings.inject({}){ |h, r| h[r.icu_id] = r; h }
  end

  def get_tournament_ratings(rorder, icu_ids)
    report_header "Getting latest player ratings from tournaments"
    t1 = Time.now
    report_item "started at:  #{t1.to_s(:tbm)}"
    ratings = Player.get_last_ratings(icu_ids, rorder)
    t2 = Time.now
    report_item "finished at: #{t2.to_s(:tbm)} (#{((t2 - t1) * 1000.0).round} ms)"
    report_item "matching subscriptions: #{ratings.size}"
    ratings
  end

  def get_legacy_ratings(icu_ids)
    report_header "Getting legacy ratings"
    total = OldRating.count
    ratings = OldRating.get_ratings(icu_ids)
    report_item "total available: #{total}"
    report_item "matching subscriptions: #{ratings.size}"
    ratings
  end

  def get_subscriptions
    season = Subscription.season(date)
    last_season = Subscription.last_season(date) if date.month == 9
    header = "Subscriptions in season #{season} (paid on or before #{payment_cut_off})"
    header << " and in season #{last_season}" if last_season
    report_header header
    subs = Subscription.get_subs(season, payment_cut_off, last_season)
    if last_season
      report_item "#{season}: #{subs.find_all{ |s| s.category == 'lifetime' || s.season == season}.count }"
      report_item "#{last_season}: #{subs.find_all{ |s| s.season == last_season}.count }"
    end
    report_item "total: #{subs.size}"
    raise "no subscriptions found" if subs.size == 0
    usubs = subs.inject(Hash.new(0)) { |h, s| h[s.icu_id] += 1; h }
    report_item "unique: #{usubs.size}"
    dups = usubs.reject{ |k, v| v == 1 }.keys
    report_examples(dups, "duplicates")
    usubs
  end

  def get_last_tournament
    report_header "Last tournament to finish on or before #{tournament_cut_off}"
    tournament = Tournament.get_last_rated(tournament_cut_off)
    raise "no last tournament found" unless tournament
    report_item "name: #{tournament.name}"
    report_item "finish date: #{tournament.finish}"
    report_item "rating order number: #{tournament.rorder}"
    @stats[:last_tournament_id] = tournament.id
    tournament.rorder
  end

  def report_header(text)
    @stats[:report] << "#{text}\n"
  end

  def report_item(text)
    @stats[:report] << "  #{text}\n"
  end

  def report_examples(array, text)
    @stats[:report] << "  #{text}: #{array.size}"
    @stats[:report] << " (#{array.sort.examples})" unless array.empty?
    @stats[:report] << "\n"
  end

  def cut_off_rules
    unless tournament_cut_off >= date.beginning_of_month && tournament_cut_off <= date.end_of_month
      errors.add(:tournament_cut_off, "must be same month as list date")
    end
    unless payment_cut_off >= date.beginning_of_month && payment_cut_off < date.beginning_of_month.advance(months: 2)
      errors.add(:payment_cut_off, "must be same month or next as list date")
    end
  end
end
