class FidePlayer < ActiveRecord::Base
  extend Util::Pagination
  extend Util::AlternativeNames

  has_many :fide_ratings, order: "period DESC", dependent: :destroy
  belongs_to :icu_player, foreign_key: "icu_id"

  default_scope order("last_name, first_name")

  validates_presence_of     :last_name
  validates_format_of       :fed, with: /^[A-Z]{3}$/
  validates_format_of       :gender, with: /^(M|F)$/
  validates_format_of       :title, with: /^W?[GIFC]M$/, allow_nil: true
  validates_numericality_of :born, only_integer: true, greater_than: 1899, less_than: 2010, allow_nil: true
  validates_numericality_of :icu_id, only_integer: true, greater_than: 0, allow_nil: true
  validates_uniqueness_of   :icu_id, allow_nil: true

  def name
    str = Array.new
    str.push last_name
    str.push first_name if first_name
    str.join(", ")
  end

  def self.search(params, path)
    matches = FidePlayer.scoped
    matches = matches.where(last_name_like(params[:last_name], params[:first_name])) unless params[:last_name].blank?
    matches = matches.where(first_name_like(params[:first_name], params[:last_name])) unless params[:first_name].blank?
    matches = matches.where("fed = ?", params[:fed]) unless params[:fed].blank?
    matches = matches.where("gender = ?", params[:gender]) unless params[:gender].blank?
    matches = matches.where("title = ?", params[:title]) unless params[:title].blank?
    matches = matches.where("born <= ?", Time.now.years_ago(params[:min_age].to_i).year) if params[:min_age].to_i > 0
    matches = matches.where("born >= ?", Time.now.years_ago(params[:max_age].to_i).year) if params[:max_age].to_i > 0
    matches = matches.where("id = ?", params[:id].to_i) if params[:id].to_i > 0
    paginate(matches, path, params)
  end
end
