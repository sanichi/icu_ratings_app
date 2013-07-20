# == Schema Information
#
# Table name: logins
#
#  id         :integer(4)      not null, primary key
#  user_id    :integer(4)
#  ip         :string(39)
#  problem    :string(8)       default("none")
#  role       :string(20)
#  created_at :datetime
#

class Login < ActiveRecord::Base
  extend ICU::Util::Pagination
  PROBLEMS = %w[none password expiry status]

  belongs_to :user

  validates_presence_of  :user_id, :ip
  validates_inclusion_of :problem, in: PROBLEMS, message: "(%{value}) is invalid"
  validates_inclusion_of :role, in: User::ROLES, message: "(%{value}) is invalid"

  default_scope -> { order("logins.created_at DESC") }

  def self.search(params, path)
    matches = all
    if params[:email].present? || params[:icu_id].to_i > 0 || params[:first_name].present? || params[:last_name].present?
      matches = matches.joins(user: :icu_player)
      matches = matches.where("users.email LIKE ?", "%#{params[:email]}%") if params[:email].present?
      matches = matches.where("users.icu_id = ?", params[:icu_id].to_i) if params[:icu_id].to_i > 0
      matches = matches.where("icu_players.first_name LIKE ?", "%#{params[:first_name]}%") if params[:first_name].present?
      matches = matches.where("icu_players.last_name LIKE ?", "%#{params[:last_name]}%") if params[:last_name].present?
    end
    matches = matches.where("logins.problem = ?", params[:problem]) if params[:problem].present?
    matches = matches.where("logins.role = ?", params[:role]) if params[:role].present?
    matches = matches.where("logins.ip LIKE ?", "%#{params[:ip]}%") if params[:ip].present?
    matches = matches.includes(user: :icu_player)
    paginate(matches, path, params)
  end
end
