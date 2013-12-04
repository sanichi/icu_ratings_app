# == Schema Information
#
# Table name: icu_ratings
#
#  id              :integer(4)  not null, primary key
#  icu_id          :integer(4)
#  rating          :integer(2)
#  games           :integer(2)
#  full            :boolean(1)  default(FALSE)
#

class LiveRating < ActiveRecord::Base
  extend ICU::Util::Pagination

  belongs_to :icu_player, foreign_key: "icu_id"

  validates :icu_id, numericality: { only_integer: true, greater_than_or_equal: 0 }, uniqueness: true
  validates :rating, numericality: { only_integer: true }
  validates :games, numericality: { only_integer: true, greater_than_or_equal: 0 }
  validates :full, inclusion: { in: [true, false] }

  default_scope -> { includes(:icu_player).joins(:icu_player).order("rating DESC, icu_players.last_name") }

  # Adapted from IcuRating#search.
  def self.search(params, path, paginated=true)
    matches = all
    matches = matches.where("first_name LIKE ?", "%#{params[:first_name]}%") if params[:first_name].present?
    matches = matches.where("last_name LIKE ?", "%#{params[:last_name]}%") if params[:last_name].present?
    matches = matches.where("club IS NULL") if params[:club] == "None"
    matches = matches.where("club = ?", params[:club]) if params[:club].present? && params[:club] != "None"
    matches = matches.where("gender = 'M' OR gender IS NULL") if params[:gender] == "M"
    matches = matches.where("gender = 'F'") if params[:gender] == "F"
    matches = matches.where(icu_id: params[:icu_id].to_i) if params[:icu_id].to_i > 0
    matches = matches.where(full: params[:type] == "full") if params[:type].present?
    matches = IcuPlayer.search_fed(matches, params[:fed])
    return matches unless paginated
    paginate(matches, path, params)
  end

  def self.recalculate
    icu_ids = get_subscriptions
    tournament_ratings = get_tournament_ratings(icu_ids)
    legacy_ratings = get_legacy_ratings(icu_ids.reject{ |id| tournament_ratings[id] })
    recent_games = get_recent_games(tournament_ratings.keys)
    unscoped.delete_all
    count = 0
    icu_ids.each do |icu_id|
      if player = tournament_ratings[icu_id]
        create(icu_id: icu_id, rating: player.new_rating, full: player.new_full, games: recent_games[icu_id])
        count += 1
      elsif rating = legacy_ratings[icu_id]
        create(icu_id: icu_id, rating: rating.rating, full: rating.full, games: 0)
        count += 1
      end
    end
    count
  end

  def type
    full ? "full" : "provisional"
  end

  private

  # Adapted from RatingList#get_subscriptions.
  def self.get_subscriptions
    date = Date.today
    season = Subscription.season(date)
    last_season = Subscription.last_season(date) if date.month >= 9 && date.month <= 12
    Subscription.get_subs(season, date, last_season).map(&:icu_id)
  end

  # Adapted from RatingList#get_tournament_ratings.
  def self.get_tournament_ratings(icu_ids)
    Player.get_last_ratings(icu_ids)
  end

  # Adapted from RatingList#get_legacy_ratings.
  def self.get_legacy_ratings(icu_ids)
    OldRating.get_ratings(icu_ids)
  end

  # Returns a hash whose default value for missing keys is zero.
  def self.get_recent_games(icu_ids)
    rorder = last_tournament_rorder
    Player.get_recent_games(icu_ids, rorder)
  end

  # Returns the rating order number of the last tournament of the last rating list.
  def self.last_tournament_rorder
    rorder = 0
    if list = RatingList.unscoped.order(date: :desc).first
      tournament = Tournament.get_last_rated(list.tournament_cut_off)
      rorder = tournament.rorder
    end
    rorder
  end
end
