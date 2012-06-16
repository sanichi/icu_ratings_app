# == Schema Information
#
# Table name: old_rating_histories
#
#  id                 :integer(4)      not null, primary key
#  old_tournament_id  :integer(4)
#  icu_player_id      :integer(4)
#  old_rating         :integer(2)
#  new_rating         :integer(2)
#  performance_rating :integer(2)
#  tournament_rating  :integer(2)
#  bonus              :integer(2)
#  games              :integer(1)
#  kfactor            :integer(1)
#  actual_score       :decimal(3, 1)
#  expected_score     :decimal(8, 6)
#

class OldRatingHistory < ActiveRecord::Base
  extend ICU::Util::Pagination

  belongs_to :old_tournament
  belongs_to :icu_player

  attr_accessible # none

  def self.search(params, path)
    matches = scoped
    if params[:icu_player_id].to_i > 0
      matches = matches.includes(:old_tournament)
      matches = matches.where(icu_player_id: params[:icu_player_id].to_i)
      matches = matches.joins(:old_tournament).order("old_tournaments.date DESC, old_tournaments.name")
    elsif params[:old_tournament_id].to_i > 0
      matches = matches.includes(:icu_player)
      matches = matches.where(old_tournament_id: params[:old_tournament_id].to_i)
      matches = matches.joins(:icu_player).order("icu_players.last_name, icu_players.first_name")
    else
      matches = matches.limit(100)
    end
    params[:per_page] ? paginate(matches, path, params) : matches
  end

  def rating_change
    new_rating - old_rating
  end
end
