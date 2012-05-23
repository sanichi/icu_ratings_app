# == Schema Information
#
# Table name: old_ratings
#
#  id     :integer(4)      not null, primary key
#  icu_id :integer(4)
#  rating :integer(2)
#  games  :integer(2)
#  full   :boolean(1)      default(FALSE)
#

class OldRating < ActiveRecord::Base
  extend ICU::Util::Pagination
  
  belongs_to :icu_player, foreign_key: "icu_id"

  validates_uniqueness_of :icu_id
  validates_numericality_of :rating, only_integer: true
  validates_numericality_of :games, only_integer: true, greater_than_or_equal_to: 0
  
  default_scope includes(:icu_player)

  def self.search(params, path)
    matches = scoped
    matches = matches.joins(:icu_player).order("last_name, first_name")
    matches = matches.where("last_name LIKE ?", "%#{params[:last_name]}%") if params[:last_name].present?
    matches = matches.where("first_name LIKE ?", "%#{params[:first_name]}%") if params[:first_name].present?
    matches = matches.where(icu_id: params[:icu_id].to_i) if params[:icu_id].to_i > 0
    matches = matches.where(full: params[:type] == "full") if params[:type].present?
    paginate(matches, path, params)
  end
  
  def type
    full ? "full" : "provisional"
  end
end
