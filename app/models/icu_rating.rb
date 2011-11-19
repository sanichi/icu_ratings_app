class IcuRating < ActiveRecord::Base
  extend Util::Pagination

  belongs_to :icu_player, foreign_key: "icu_id"
  validates_numericality_of :list, :rating, only_integer: true
  default_scope includes(:icu_player).joins(:icu_player).order("list DESC, rating DESC")

  def self.search(params, path)
    matches = scoped
    matches = matches.where("first_name LIKE ?", "%#{params[:first_name]}%") if params[:first_name].present?
    matches = matches.where("last_name LIKE ?", "%#{params[:last_name]}%") if params[:last_name].present?
    matches = matches.where("club LIKE ?", "%#{params[:club]}%") if params[:club].present?
    matches = matches.where(icu_id: params[:icu_id].to_i) if params[:icu_id].to_i > 0
    matches = matches.where(full: params[:type] == "full") if params[:type].present?
    matches = matches.where(list: params[:list].to_i) if params[:list].present?
    if params[:fed].present?
      case params[:fed]
      when "???"
        matches = matches.where("fed IS NULL")
      when "IR?"
        matches = matches.where("fed IS NULL OR fed = 'IRL'")
      when "XXX"
        matches = matches.where("fed IS NOT NULL AND fed != 'IRL'")
      else
        matches = matches.where("fed = ?", params[:fed])
      end
    end
    paginate(matches, path, params)
  end

  def type
    full ? "full" : "provisional"
  end

  def self.lists
    unscoped.select("DISTINCT(list)").order("list DESC").map(&:list)
  end
end
