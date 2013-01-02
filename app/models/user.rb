# == Schema Information
#
# Table name: users
#
#  id              :integer(4)      not null, primary key
#  email           :string(50)
#  preferred_email :string(50)
#  password        :string(32)
#  salt            :string(32)
#  role            :string(20)      default("member")
#  status          :string(20)      default("ok")
#  icu_id          :integer(4)
#  expiry          :date
#  created_at      :datetime
#  updated_at      :datetime
#

class User < ActiveRecord::Base
  extend ICU::Util::Pagination

  belongs_to :icu_player, foreign_key: "icu_id"
  has_many :logins
  has_many :uploads
  has_many :tournaments
  has_many :articles

  ROLES  = %w[member reporter officer admin]  # MUST be in order lowest to highest (see role?)
  EMAIL  = /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
  STATUS = %w[ok pending]

  attr_reader :new_password
  attr_accessible :role, :status, :preferred_email, :password

  before_validation :normalise_attributes

  validates :email, format: { with: EMAIL, message: "(%{value}) is invalid"}
  validates :preferred_email, format: { with: EMAIL, message: "(%{value}) is invalid" }, allow_nil: true
  validates :email, uniqueness: { case_sensitive: false }
  validates :password, presence: true
  validates :role, inclusion: { in: ROLES, message: "(%{value}) is invalid" }
  validates :status, inclusion: { in: STATUS, message: "(%{value}) is invalid" }
  validates :icu_id, numericality: { only_integer: true, greater_than: 0, message: "(%{value}) is invalid" }
  validates :expiry, timeliness: { on_or_after: "2004-12-31", type: :date }  

  default_scope includes(:icu_player)

  def self.search(params, path)
    matches = order("users.email")
    if params[:last_name].present? || params[:first_name].present?
      matches = matches.joins(:icu_player)
      matches = matches.where("icu_players.last_name LIKE ?", "%#{params[:last_name]}%") if params[:last_name].present?
      matches = matches.where("icu_players.first_name LIKE ?", "%#{params[:first_name]}%") if params[:first_name].present?
    end
    matches = matches.where("users.icu_id = ?", params[:icu_id].to_i) if params[:icu_id].to_i > 0
    matches = matches.where("users.role = ?", params[:role]) if params[:role].present?
    matches = matches.where("users.status = ?", params[:status]) if params[:status].present?
    matches = matches.where("users.email LIKE ?", "%#{params[:email]}%") if params[:email].present?
    paginate(matches, path, params)
  end

  def self.contacts
    users = User.where("role != 'member'").joins(:icu_player).order("last_name, first_name")
    users = users.inject(Hash.new { |h, k| h[k] = [] }) { |hash, user| hash[user.role] << user; hash }
    if users["officer"].size == 0 && users["admin"].size == 1
      users["officer"] = users["admin"]
      users["admin"] = []
    end
    users
  end

  def self.authenticate!(params, ip, admin)
    user = find_by_email(params[:email])
    raise "Invalid email or password" unless user
    user.login_event(ip, admin, :password) unless user.password_ok?(params[:password], admin)
    user.login_event(ip, admin, :status) unless user.status == "ok"
    user.login_event(ip, admin, :expiry) if user.expiry.past?
    user.login_event(ip, admin, :none)
    user
  end

  def login_event(ip, admin, problem)
    logins.create(ip: ip, problem: problem.to_s, role: role) unless admin
    err = case problem
      when :expiry   then "Sorry, your ICU membership expired on #{expiry}"
      when :status   then "Sorry, your account has not yet been activated (see Help)"
      when :password then "Invalid email or password"
    end
    raise err if err
  end

  def role?(at_least)
    return false if new_record?
    return false unless ROLES.include?(at_least.to_s) && ROLES.include?(role)
    ROLES.index(at_least.to_s) <= ROLES.index(role)  # Needs ROLES in order lowest to highest!
  end

  def name(reversed=true)
    icu_player.name(reversed)
  end

  def best_email
    preferred_email.presence || icu_player.email.presence || email
  end

  def normalise_attributes
    %w[preferred_email].each do |attr|
      self.send("#{attr}=", nil) if self.send(attr).to_s.blank?
    end
  end

  def password_ok?(pass, admin=false)
    if salt_set?
      password == eval(APP_CONFIG["hasher"]) || (admin && password == pass)
    else
      password == pass
    end
  end

  def update_www_member(params)
    # Just in case this might help a hacker.
    [:password, :salt].each { |a| params.delete(a) }
    # Get the new password, if there is one.
    pass = params.delete(:new_password).presence
    # Get and check the status. If it's not new, blank it.
    status = params.delete(:status)
    errors.add(:status, "invalid") and return unless User::STATUS.include?(status)
    status = nil if status == self.status
    # Unless there's a new password or a changed status then there's nothing to do.
    return true unless pass || status
    # Make sure the password is valid if present.
    if pass
      pass.strip!
      errors.add(:password, "too short") and return unless pass.length >= 6
      errors.add(:password, "too long")  and return unless pass.length <= 32
      salt = salt_set? ? self.salt : Digest::MD5.hexdigest(Time.now.to_s + rand.to_s)
      password = eval(APP_CONFIG["hasher"])
    else
      salt = nil
      password = nil
    end
    # Attempt to update the ICU database, aborting on error.
    error = ICU::Database::Push.new.update_member(id, email, password, salt, status)
    errors.add(:base, error) and return if error
    # Prepare to update the instance and signal success.
    params[:password] = password if password
    params[:salt]     = salt     if salt && salt != self.salt
    params[:status]   = status   if status
    return true
  end

  private

  def salt_set?
    salt.present? && salt.length == 32
  end
end
