# == Schema Information
#
# Table name: rating_runs
#
#  id                      :integer(4)      not null, primary key
#  user_id                 :integer(4)
#  status                  :string(255)
#  reason                  :string(100)     not null, default ""
#  report                  :text
#  start_tournament_id     :integer(4)
#  last_tournament_id      :integer(4)
#  start_tournament_rorder :integer(4)
#  last_tournament_rorder  :integer(4)
#  start_tournament_name   :string(255)
#  last_tournament_name    :string(255)
#  created_at              :datetime        not null
#  updated_at              :datetime        not null
#

class RatingRun < ActiveRecord::Base
  extend ICU::Util::Pagination

  STATUS = %w[waiting processing error finished]

  attr_accessible :start_tournament_id, :user_id, :reason

  belongs_to :user
  belongs_to :start_tournament, class_name: "Tournament"
  belongs_to :last_tournament, class_name: "Tournament"

  before_create :complete
  after_create :throw_flag
  before_update :truncate_reason

  default_scope order("created_at DESC")

  def self.search(params, path)
    matches = scoped.includes(:user)
    matches = matches.where(status: params[:status]) if STATUS.include?(params[:status])
    paginate(matches, path, params)
  end

  def self.flag(append=false)
    # When cron first detects the flag it should rename it (by appending "_") before invoking lib/icu/rating_run.rb.
    # Cron is absent for tests and cannot rename the file so always use the same name.
    append = true if Rails.env == "test"
    Rails.root + "tmp" + "#{Rails.env}_rating_run#{append ? '_' : ''}"
  end

  def duration
    secs = (updated_at - created_at).to_i
    "#{secs} second#{secs == 1 ? '' : 's'}"
  end

  def process
    self.status = "processing"
    t = start_tournament
    r = start_tournament_rorder
    m = last_tournament_rorder - start_tournament_rorder + 1
    n = 1
    add("Rating #{m} tournament#{m == 1 ? '' : 's'}")
    while t
      raise ICU::Error.new("expected #{t.name} to have rating order #{r}") unless t.rorder == r
      raise ICU::Error.new("expected #{t.name} to be next for rating")     unless t == Tournament.next_for_rating
      t.rate!
      add("#{n} #{t.name_with_year}")
      t = t.next_tournament
      n+= 1
      r+= 1
      raise ICU::Error.new("expected to finish just before #{t.name}") if n > m && t
    end
    add("Finished", false)
    finish
  rescue => e
    Failure.record(e) unless e.instance_of?(ICU::Error)
    add("Error: #{e.message}", false)
    finish(false)
  end

  def finish(ok=true)
    self.status = ok ? "finished" : "error"
    save
  end

  def add(info, save=true)
    self.report = "#{report}#{Time.now.getutc.strftime('%H:%M:%S.%L')} #{info}\n"
    self.save if save
  end

  def rivals
    RatingRun.where("id != #{id}").where("status IN ('waiting', 'processing')")
  end

  def deletable?
    status == "error" || status == "finished"
  end

  private

  # New objects (only created from a special button in tourament view) are completed here.
  def complete
    error = complete_with_error
    if error
      self.status = "error"
      add("Initialisation error: #{error}", false)
    else
      self.status = "waiting"
      add("Initialised", false)
    end
  end

  # Helper for the complete method.
  def complete_with_error
    # Sanity check.
    return "no start tournament ID"                                  unless start_tournament_id.present?
    return "couldn't find tournament with ID #{start_tournament_id}" unless start_tournament = Tournament.where(id: start_tournament_id).first
    return "couldn't determine last tournament for rating"           unless last_tournament = Tournament.last_for_rating
    return "the start tournament is not the next for rating"         unless start_tournament == Tournament.next_for_rating
    return "the last tournament doesn't come after the start"        unless last_tournament.rorder > start_tournament.rorder
    return "no user ID"                                              unless user_id.present?
    return "couldn't find user with ID #{user_id}"                   unless User.find(user_id)

    # Set missing parameters that have now been verified.
    self.last_tournament_id = last_tournament.id

    # Remember some additional details of the tournaments as they are now because they might change later.
    self.start_tournament_name   = start_tournament.name_with_year
    self.start_tournament_rorder = start_tournament.rorder
    self.last_tournament_name    = last_tournament.name_with_year
    self.last_tournament_rorder  = last_tournament.rorder

    # Signal no error.
    false
  end

  # Assuming all is well, we throw a flag so a background process can rate the tournaments.
  def throw_flag
    File.open(RatingRun.flag, "w") { |f| f.write id }
  end

  # Make sure the reason is within limit.
  def truncate_reason
    self.reason = reason[0, 100] if reason && reason.length > 100
  end
end
