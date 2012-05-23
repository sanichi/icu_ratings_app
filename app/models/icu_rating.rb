# == Schema Information
#
# Table name: icu_ratings
#
#  id     :integer(4)      not null, primary key
#  list   :date
#  icu_id :integer(4)
#  rating :integer(2)
#  full   :boolean(1)      default(FALSE)
#

class IcuRating < ActiveRecord::Base
  extend ICU::Util::Pagination

  belongs_to :icu_player, foreign_key: "icu_id"

  validates_numericality_of :rating, only_integer: true
  validates_date            :list, on_or_after: "2001-09-01", on_or_before: :today
  validate                  :list_should_be_first_of_month

  default_scope includes(:icu_player).joins(:icu_player).order("list DESC, rating DESC")

  def self.search(params, path)
    matches = scoped
    matches = matches.where("first_name LIKE ?", "%#{params[:first_name]}%") if params[:first_name].present?
    matches = matches.where("last_name LIKE ?", "%#{params[:last_name]}%") if params[:last_name].present?
    matches = matches.where("club IS NULL") if params[:club] == "None"
    matches = matches.where("club = ?", params[:club]) if params[:club].present? && params[:club] != "None"
    matches = matches.where("gender = 'M' OR gender IS NULL") if params[:gender] == "M"
    matches = matches.where("gender = 'F'") if params[:gender] == "F"
    matches = matches.where(icu_id: params[:icu_id].to_i) if params[:icu_id].to_i > 0
    matches = matches.where(full: params[:type] == "full") if params[:type].present?
    matches = matches.where(list: params[:list]) if params[:list].present?
    matches = IcuPlayer.search_fed(matches, params[:fed])
    paginate(matches, path, params)
  end

  def type
    full ? "full" : "provisional"
  end

  def self.lists
    unscoped.select("DISTINCT(list)").order("list DESC").map(&:list)
  end

  private

  def list_should_be_first_of_month
    errors.add(:list, "should be 1st day of month") unless list.day == 1
  end
end
