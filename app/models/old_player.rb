# == Schema Information
#
# Table name: old_players
#
#  id            :integer(4)      not null, primary key
#  icu_id        :integer(4)
#  first_name    :string(255)
#  last_name     :string(255)
#  club          :string(255)
#  gender        :string(1)
#  dob           :date
#  joined        :date
#  note          :text
#  ratings       :integer(2)
#  events        :integer(2)
#  games         :integer(2)
#  resurrected   :integer(1)
#  created_at    :datetime
#  updated_at    :datetime
#

class OldPlayer < ActiveRecord::Base
  extend ICU::Util::Pagination
  extend ICU::Util::AlternativeNames

  STATUS = %w[archived resurrected duplicate]
  
  attr_accessible :status, :note

  validates :first_name, :last_name, presence: true
  validates :icu_id, numericality: { only_integer: true, greater_than: 0 }, uniqueness: true
  validates :rating, numericality: { only_integer: true, greater_than: 0 }
  validates :events, :games, numericality: { only_integer: true, greater_than_or_equal: 0 }
  validates :gender, inclusion: { in: ["M", "F"] }, allow_nil: true
  validates :dob, timeliness: { on_or_after: "1900-01-01", on_or_before: :today, type: :date }, allow_nil: true
  validates :joined, timeliness: { on_or_after: "1960-01-01", on_or_before: :today, type: :date }, allow_nil: true
  validates :status, :inclusion => { :in => STATUS }

  def self.search(params, path)
    matches = unscoped
    matches = matches.where(last_name_like(params[:last_name], params[:first_name])) if params[:last_name].present?
    matches = matches.where(first_name_like(params[:first_name], params[:last_name])) if params[:first_name].present?
    matches = matches.where("gender = 'M' OR gender IS NULL") if params[:gender] == "M"
    matches = matches.where("gender = 'F'") if params[:gender] == "F"
    matches = matches.where("dob LIKE ?", "%#{params[:dob]}%") if params[:dob] && params[:dob].match(/^[-\d]+$/)
    matches = matches.where(icu_id: params[:icu_id]) if params[:icu_id].to_i > 0
    matches = matches.where("club LIKE ?", "%#{params[:club]}%") if params[:club].present?
    matches = matches.where("note LIKE ?", "%#{params[:note]}%") if params[:note].present?
    matches = matches.where(resurrected: true) if params[:resurrected] == "true"
    matches = matches.where(resurrected: false) if params[:resurrected] == "false"
    paginate(matches, path, params)
  end

  def name(reversed=true)
    reversed ? "#{last_name}, #{first_name}" : "#{first_name} #{last_name}"
  end

  def abbreviated_note
    return "" unless note.present?
    note.truncate(20)
  end
end
