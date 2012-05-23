# == Schema Information
#
# Table name: fide_ratings
#
#  id         :integer(4)      not null, primary key
#  fide_id    :integer(4)
#  rating     :integer(2)
#  games      :integer(2)
#  list       :date
#  created_at :datetime
#  updated_at :datetime
#

class FideRating < ActiveRecord::Base
  extend ICU::Util::Pagination

  belongs_to :fide_player, foreign_key: "fide_id"

  validates_numericality_of :fide_id, only_integer: true, greater_than: 0
  validates_numericality_of :rating, only_integer: true, greater_than: 0, less_than: 3000
  validates_numericality_of :games, only_integer: true, greater_than_or_equal_to: 0, less_than: 100
  validates_date            :list, on_or_after: "1950-01-01", on_or_before: :today
  validates_uniqueness_of   :list, scope: :fide_id
  validate                  :list_should_be_first_of_month

  default_scope includes(:fide_player).joins(:fide_player).order("list DESC, fide_ratings.rating DESC")

  def self.search(params, path)
    matches = scoped
    matches = matches.where(list: params[:list]) if params[:list].present?
    matches = matches.where(fide_id: params[:fide_id].to_i) if params[:fide_id].to_i > 0
    matches = matches.where("first_name LIKE ?", "%#{params[:first_name]}%") if params[:first_name].present?
    matches = matches.where("last_name LIKE ?", "%#{params[:last_name]}%") if params[:last_name].present?
    matches = matches.where("gender = ?", params[:gender]) if params[:gender].present?
    paginate(matches, path, params)
  end

  def self.lists
    unscoped.select("DISTINCT(list)").order("list DESC").map(&:list)
  end

  private

  def list_should_be_first_of_month
    errors.add(:list, "should be 1st day of month") unless list.day == 1
  end
end
