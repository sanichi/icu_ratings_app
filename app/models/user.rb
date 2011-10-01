class User < ActiveRecord::Base
  extend Util::Pagination

  belongs_to :icu_player, foreign_key: "icu_id"
  has_many :logins
  has_many :uploads
  has_many :tournaments
  has_many :news_items

  ROLES = %w{member reporter officer admin}  # MUST be in order lowest to highest (see role?)
  EMAIL = /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i

  attr_accessible :role, :preferred_email
  
  before_validation :normalise_attributes

  validates_format_of       :email, with: EMAIL, message: "(%{value}) is invalid"
  validates_format_of       :preferred_email, with: EMAIL, allow_nil: true, message: "(%{value}) is invalid"
  validates_uniqueness_of   :email, case_sensitive: false
  validates_presence_of     :password
  validates_inclusion_of    :role, in: ROLES, message: "(%{value}) is invalid"
  validates_numericality_of :icu_id, only_integer: true, greater_than: 0, message: "(%{value}) is invalid"
  validates_date            :expiry, on_or_after: "2004-12-31", message: "(%{value}) is invalid"

  default_scope includes(:icu_player)

  def self.search(params, path)
    matches = User.order(:email)
    matches = matches.where("users.icu_id = ?", params[:icu_id].to_i) if params[:icu_id].to_i > 0
    matches = matches.where("users.role = ?", params[:role]) if params[:role].present?
    matches = matches.where("users.email LIKE ?", "%#{params[:email]}%") if params[:email].present?
    paginate(matches, path, params)
  end

  def self.contacts
    users = User.where("role != 'member'").joins(:icu_player).order("last_name, first_name")
    users = users.inject(Hash.new { |h, k| h[k] = [] }) { |hash, user| hash[user.role] << user; hash }
    users["officer"] = users["admin"] if users["officer"].size == 0
    users
  end

  def self.authenticate!(params, ip, switch)
    user = find_by_email(params[:email])
    raise "Invalid email or password" unless user
    user.login_event(ip, switch, "password") unless user.password == params[:password]
    user.login_event(ip, switch, "expiry") if user.expiry.past?
    user.login_event(ip, switch, "none")
    user
  end

  def role?(base_role)
    return false unless ROLES.include?(base_role.to_s) && ROLES.include?(role)
    ROLES.index(base_role.to_s) <= ROLES.index(role)  # Needs ROLES in order lowest to highest!
  end

  def login_event(ip, switch, problem)
    logins.create(ip: ip, problem: problem, role: role) unless switch
    raise "Sorry, your ICU membership expired on #{expiry}" if problem == "expiry"
    raise "Invalid email or password" if problem == "password"
  end

  def name(reversed=true)
    icu_player.name(reversed)
  end

  def best_email
    preferred_email.presence || icu_player.email.presence || email
  end
  
  def normalise_attributes
    %w{preferred_email}.each do |attr|
      self.send("#{attr}=", nil) if self.send(attr).to_s.blank?
    end
  end
end
