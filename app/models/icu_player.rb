class IcuPlayer < ActiveRecord::Base
  extend Util::Pagination
  extend Util::AlternativeNames

  belongs_to :master, class_name: "IcuPlayer", foreign_key: :master_id
  has_many   :duplicates, class_name: "IcuPlayer"
  has_many   :players, foreign_key: "icu_id"
  has_many   :users, foreign_key: "icu_id"
  has_one    :fide_player, foreign_key: "icu_id"
  has_many   :old_rating_histories
  has_many   :old_tournaments, through: :old_rating_histories

  default_scope order("last_name, first_name")

  validates_presence_of     :first_name
  validates_presence_of     :last_name
  validates_format_of       :fed, with: /^[A-Z]{3}$/, allow_nil: true
  validates_format_of       :title, with: /^W?[GIFCN]M$/, allow_nil: true
  validates_format_of       :gender, with: /^(M|F)$/, allow_nil: true
  validates_inclusion_of    :deceased, in: [true, false]
  validates_numericality_of :master_id, only_integer: true, greater_than: 0, allow_nil: true
  validates_date            :dob, on_or_after: "1900-01-01", allow_nil: true
  validates_date            :joined, on_or_after: "1960-01-01", allow_nil: true

  def name(reversed=true)
    reversed ? "#{last_name}, #{first_name}" : "#{first_name} #{last_name}"
  end

  def self.search(params, path)
    matches = IcuPlayer.scoped
    matches = matches.where(master_id: nil) unless params[:include_duplicates]
    matches = matches.where(deceased: false) unless params[:include_deceased]
    matches = matches.where(last_name_like(params[:last_name], params[:first_name])) unless params[:last_name].blank?
    matches = matches.where(first_name_like(params[:first_name], params[:last_name])) unless params[:first_name].blank?
    matches = matches.where("club LIKE ?", "%#{params[:club]}%") unless params[:club].blank?
    matches = matches.where("fed = ?", params[:fed]) unless params[:fed].blank? || params[:fed] == "IRL"
    matches = matches.where("fed = 'IRL' OR fed IS NULL") if params[:fed] == "IRL"
    matches = matches.where("gender = ?", params[:gender]) unless params[:gender].blank? || params[:gender] == "M"
    matches = matches.where("gender = 'M' OR gender IS NULL") if params[:gender] == "M"
    matches = matches.where("title = ?", params[:title]) unless params[:title].blank?
    matches = matches.where("dob < ?", Time.now.years_ago(params[:min_age].to_i)) if params[:min_age].to_i > 0
    matches = matches.where("dob > ?", Time.now.years_ago(params[:max_age].to_i)) if params[:max_age].to_i > 0
    matches = matches.where("dob LIKE ?", "%#{params[:dob]}%") if params[:dob] && params[:dob].match(/^[-\d]+$/)
    matches = matches.where("id = ?", params[:id].to_i) if params[:id].to_i > 0
    paginate(matches, path, params)
  end
end
