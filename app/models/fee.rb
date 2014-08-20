# == Schema Information
#
# Table name: fees
#
# string   "description"
# string   "status",      :limit => 25
# string   "category",    :limit => 3
# date     "date"
# integer  "icu_id"
# boolean  "used"         :default => false
# datetime "created_at",  :null => false
# datetime "updated_at",  :null => false
#

class Fee < ActiveRecord::Base
  extend ICU::Util::Pagination

  belongs_to :icu_player, foreign_key: "icu_id"

  validates :description, :status, :category, presence: true
  validates :date, date: { on_or_after: "2008-01-01" }
  validates :icu_id, numericality: { only_integer: true, greater_than: 0 }

  def self.search(params, path)
    matches = joins(:icu_player).includes(:icu_player)
    matches = matches.where("icu_players.last_name LIKE ?", "%#{params[:last_name]}%") if params[:last_name].present?
    matches = matches.where("icu_players.first_name LIKE ?", "%#{params[:first_name]}%") if params[:first_name].present?
    matches = matches.where("fees.description LIKE ?", "%#{params[:description]}%") if params[:description].present?
    matches = matches.where(status: params[:status]) if params[:status].present?
    matches = matches.where(used: true) if params[:used] == "true"
    matches = matches.where(used: false) if params[:used] == "false"
    matches = matches.order("fees.date DESC")
    paginate(matches, path, params)
  end
end
