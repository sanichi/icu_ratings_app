class FidePlayer < ActiveRecord::Base
  extend Util::Pagination
  extend Util::AlternativeNames

  has_many :fide_ratings, foreign_key: "fide_id", order: "period DESC", dependent: :destroy
  belongs_to :icu_player, foreign_key: "icu_id"

  default_scope order("last_name, first_name")

  validates_presence_of     :last_name
  validates_format_of       :fed, with: /^[A-Z]{3}$/
  validates_format_of       :gender, with: /^(M|F)$/
  validates_format_of       :title, with: /^W?[GIFC]M$/, allow_nil: true
  validates_numericality_of :born, only_integer: true, greater_than: 1899, less_than: 2010, allow_nil: true
  validates_numericality_of :icu_id, only_integer: true, greater_than: 0, allow_nil: true
  validates_uniqueness_of   :icu_id, allow_nil: true

  def name(*args)
    args.push :reversed if args.empty?
    args[0] = :reversed if args.size == 1 && args.first == true
    args.shift if args.size == 1 && args.first == false
    name = args.include?(:reversed) ? "#{last_name}, #{first_name}" : "#{first_name} #{last_name}"
    more = args.inject([]) do |m, a|
      case a
      when :title then m.push title if title
      end
      m
    end
    more = more.empty? ? nil : more.join(", ")
    if more
      if args.include?(:brackets)
        "#{name} (#{more})"
      else
        "#{name}, #{more}"
      end
    else
      name
    end
  end

  def self.search(params, path)
    matches = scoped
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
