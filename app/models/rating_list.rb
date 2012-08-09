# == Schema Information
#
# Table name: rating_lists
#
#  id         :integer(4)      not null, primary key
#  date       :date
#  cut_off    :date
#  created_at :datetime
#  updated_at :datetime
#

class RatingList < ActiveRecord::Base
  extend ICU::Util::Pagination

  has_many :publications, dependent: :destroy

  attr_accessible :cut_off

  validates :date, timeliness: { on_or_after: "2012-01-01", on_or_before: :today, type: :date }
  validates :date, list_date: true
  validates :cut_off, timeliness: { type: :date }
  validate  :cut_off_must_be_same_month_as_date

  default_scope order("date DESC")

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
    todo.each { |date| create({date: date, cut_off: date.change(day: 15)}, without_protection: true) }
  end

  def self.search(params, path)
    matches = scoped
    matches = matches.where("date LIKE '#{params[:year]}%'") if params[:year].present?
    paginate(matches, path, params)
  end

  def next_list
    RatingList.unscoped.where("date > ?", date).order("date ASC").limit(1).first
  end

  def prev_list
    RatingList.unscoped.where("date < ?", date).order("date DESC").limit(1).first
  end

  private

  def publish_list
    subs = get_subscriptions
    icu_ids = subs.keys
    rorder = get_last_tournament + 1
    tournament_ratings = get_tournament_ratings(rorder, icu_ids)
    legacy_ratings = get_legacy_ratings(icu_ids)
    t1 = Time.now
    @stats[:report] << "Starting rating updates at #{t1.to_s(:tbm)}\n"

    legacy, tournaments = 0, 0
    changes = Hash.new { |h, k| h[k] = [] }
    no_rating, creates, remains, updates, deletes = [], [], [], [], []
    subs.keys.each do |icu_id|
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
        deletes.push icu_id
      when !current && rating
        hash = { list: date, icu_id: icu_id, rating: rating, full: full }
        hash[:original_rating] = @originals ? rating : nil
        hash[:original_full] = @originals ? full : nil
        IcuRating.create!(hash, without_protection: true)
        creates.push icu_id
      when
        !current && !rating
        no_rating.push icu_id
      end

      @current.delete(icu_id) if current
    end
    @stats[:report] << "  tournament ratings used: #{tournaments}\n"
    @stats[:report] << "  legacy ratings used: #{legacy}\n"
    report_with_examples(no_rating, "subscribed members with no rating")

    no_sub = []
    @current.each_pair do |icu_id, rating|
      no_sub.push(icu_id)
      rating.destroy
      @stats[:deletes] += 1
    end
    report_with_examples(no_sub, "existing ratings with no subscription")

    t2 = Time.now
    @stats[:report] << "  finished rating updates at #{t2.to_s(:tbm)} (#{((t2 - t1) * 1000.0).round} ms)\n"

    @stats[:report] << "Statistics\n"
    report_with_examples(creates, "new")
    report_with_examples(remains, "unchanged")
    report_with_examples(updates, "changed")
    report_with_examples(deletes, "deleted")
    unless changes.empty?
      @stats[:report] << "Change statistics\n"
      changes.keys.sort.each { |bucket| report_with_examples(changes[bucket], bucket) }
    end

    @stats[:creates] = creates.size
    @stats[:remains] = remains.size
    @stats[:updates] = updates.size
    @stats[:deletes] = deletes.size
    @stats[:total] = @stats[:creates] + @stats[:remains] + @stats[:updates]
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
    @stats[:report] << "Detected pre-loaded ratings\n"
    @stats[:total] = @current.size;
    @stats[:remains] = @current.size;
    @stats[:report] << "  these will be used (unchanged) as the first publication\n"
  end

  def first_publication?
    previous = publications.count
    @stats[:report] << "  previous publications of this list: #{previous}\n"
    previous == 0
  end

  def set_original_ratings?(today)
    set = today <= date || (today.year == date.year && today.month == date.month)
    @stats[:report] << "  original ratings will be #{set ? 'set' : 'kept'}\n"
    set
  end

  def get_current_ratings
    ratings = IcuRating.unscoped.where(list: date).all
    @stats[:report] << "  existing ratings: #{ratings.size}\n"
    ratings.inject({}){ |h, r| h[r.icu_id] = r; h }
  end

  def get_tournament_ratings(rorder, icu_ids)
    @stats[:report] << "Getting latest player ratings from tournaments\n"
    t1 = Time.now
    @stats[:report] << "  started at:  #{t1.to_s(:tbm)}\n"
    ratings = Player.get_last_ratings(icu_ids, rorder)
    t2 = Time.now
    @stats[:report] << "  finished at: #{t2.to_s(:tbm)} (#{((t2 - t1) * 1000.0).round} ms)\n"
    @stats[:report] << "  matching subscriptions: #{ratings.size}\n"
    ratings
  end

  def get_legacy_ratings(icu_ids)
    @stats[:report] << "Getting legacy ratings\n"
    total = OldRating.count
    ratings = OldRating.get_ratings(icu_ids)
    @stats[:report] << "  total available: #{total}\n"
    @stats[:report] << "  matching subscriptions: #{ratings.size}\n"
    ratings
  end

  def get_subscriptions
    season = Subscription.season(date)
    pay_date = date.next_month
    @stats[:report] << "Subscriptions in season #{season} paid before #{pay_date}\n"
    subs = Subscription.where("category = 'lifetime' OR (season = ? AND (pay_date IS NULL OR pay_date < ?))", season, pay_date).all
    @stats[:report] << "  total: #{subs.size}\n"
    raise "no subscriptions found" if subs.size == 0
    usubs = subs.inject(Hash.new(0)) { |h, s| h[s.icu_id] += 1; h }
    @stats[:report] << "  unique: #{usubs.size}\n"
    dups = usubs.reject{ |k, v| v == 1 }.keys
    report_with_examples(dups, "duplicates")
    usubs
  end

  def get_last_tournament
    @stats[:report] << "Last tournament to finish on or before #{cut_off}\n"
    tournament = Tournament.where(stage: "rated").where("finish <= ?", cut_off).order("rorder DESC").first
    raise "no last tournament found" unless tournament
    @stats[:report] << "  name: #{tournament.name}\n"
    @stats[:report] << "  finish date: #{tournament.finish}\n"
    @stats[:report] << "  rating order number: #{tournament.rorder}\n"
    @stats[:last_tournament_id] = tournament.id
    tournament.rorder
  end

  def report_with_examples(array, text)
    @stats[:report] << "  #{text}: #{array.size}"
    @stats[:report] << " (#{array.sort.examples})" unless array.empty?
    @stats[:report] << "\n"
  end

  def cut_off_must_be_same_month_as_date
    errors.add(:cut_off, "must be same month as list date") unless date.month == cut_off.month
  end
end
