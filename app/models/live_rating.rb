# == Schema Information
#
# Table name: icu_ratings
#
#  id              :integer(4)  not null, primary key
#  icu_id          :integer(4)
#  rating          :integer(2)
#  full            :boolean     default(FALSE)
#  last_rating     :integer(2)
#  last_full       :boolean     default(FALSE)
#  games           :integer(2)
#

class LiveRating < ActiveRecord::Base
  extend ICU::Util::Pagination

  belongs_to :icu_player, foreign_key: "icu_id"

  validates :icu_id, numericality: { only_integer: true, greater_than_or_equal: 0 }, uniqueness: true
  validates :rating, numericality: { only_integer: true }
  validates :last_rating, numericality: { only_integer: true }, allow_nil: true
  validates :games, numericality: { only_integer: true, greater_than_or_equal: 0 }
  validates :full, inclusion: { in: [true, false] }
  validates :last_full, inclusion: { in: [true, false] }, allow_nil: true

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
    last_list = get_last_list
    tournament_ratings = get_tournament_ratings(icu_ids)
    published_ratings = get_published_ratings(last_list)
    legacy_ratings = get_legacy_ratings(icu_ids.reject{ |id| tournament_ratings[id] })
    recent_games = get_recent_games(tournament_ratings.keys, last_list)
    current = unscoped.to_a.each_with_object({}) { |live_rating, hash| hash[live_rating.icu_id] = live_rating }
    done = []
    icu_ids.each do |icu_id|
      old = published_ratings[icu_id]
      if live_rating = current[icu_id]
        attrs = {}
        attrs[:last_rating] = old.try(:rating)  unless live_rating.last_rating == old.try(:rating)
        attrs[:last_full]   = old.try(:full)    unless live_rating.last_full   == old.try(:full)
        if player = tournament_ratings[icu_id]
          attrs[:rating] = player.new_rating    unless live_rating.rating == player.new_rating
          attrs[:full]   = player.new_full      unless live_rating.full   == player.new_full
          attrs[:games]  = recent_games[icu_id] unless live_rating.games  == recent_games[icu_id]
        elsif rating = legacy_ratings[icu_id]
          attrs[:rating] = rating.rating        unless live_rating.rating == rating.rating
          attrs[:full]   = rating.full          unless live_rating.full   == rating.full
          attrs[:games]  = 0                    unless live_rating.games  == 0
        else
          attrs = nil
        end
        if attrs
          live_rating.update(attrs) if attrs.size > 0
          done.push icu_id
        end       
      else
        attrs = { icu_id: icu_id, last_rating: old.try(:rating), last_full: old.try(:full) }
        if player = tournament_ratings[icu_id]
          attrs.merge!(rating: player.new_rating, full: player.new_full, games: recent_games[icu_id])
        elsif rating = legacy_ratings[icu_id]
          attrs.merge!(rating: rating.rating, full: rating.full, games: 0)
        else
          attrs = nil
        end
        if attrs
          create(attrs)
          done.push icu_id
        end
      end
    end
    to_delete = current.keys - done
    unscoped.where("icu_id IN (?)", to_delete).delete_all unless to_delete.empty?
    done.count
  end

  def type
    full ? "full" : "provisional"
  end

  def last_type
    last_full ? "full" : "provisional"
  end

  # Don't use RatingList.last_list as there might be an empty, as yet unpublished list sitting around.
  def self.get_last_list
    last_date = IcuRating.maximum(:list)
    RatingList.find_by(date: last_date)
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

  def self.get_published_ratings(last_list)
    return {} unless last_list
    IcuRating.unscoped.where(list: last_list.date).each_with_object({}) do |rating, hash|
      hash[rating.icu_id] = rating
    end
  end

  # Adapted from RatingList#get_legacy_ratings.
  def self.get_legacy_ratings(icu_ids)
    OldRating.get_ratings(icu_ids)
  end

  # Returns a hash whose default value for missing keys is zero.
  def self.get_recent_games(icu_ids, last_list)
    rorder = last_tournament_rorder(last_list)
    Player.get_recent_games(icu_ids, rorder)
  end

  # Returns the rating order number of the last tournament of the last rating list.
  def self.last_tournament_rorder(last_list)
    return 0 unless last_list
    Tournament.get_last_rated(last_list.tournament_cut_off).rorder
  end
end
