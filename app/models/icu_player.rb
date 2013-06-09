# == Schema Information
#
# Table name: icu_players
#
#  id            :integer(4)      not null, primary key
#  first_name    :string(255)
#  last_name     :string(255)
#  email         :string(255)
#  club          :string(255)
#  address       :string(255)
#  phone_numbers :string(255)
#  fed           :string(3)
#  title         :string(3)
#  gender        :string(1)
#  note          :text
#  dob           :date
#  joined        :date
#  deceased      :boolean(1)
#  master_id     :integer(4)
#  created_at    :datetime
#  updated_at    :datetime
#

class IcuPlayer < ActiveRecord::Base
  extend ICU::Util::Pagination
  extend ICU::Util::AlternativeNames

  belongs_to :master, class_name: "IcuPlayer", foreign_key: :master_id
  has_many   :duplicates, class_name: "IcuPlayer"
  has_many   :players, foreign_key: "icu_id"
  has_many   :users, foreign_key: "icu_id"
  has_many   :icu_ratings, foreign_key: "icu_id"
  has_one    :fide_player, foreign_key: "icu_id"
  has_one    :old_rating, foreign_key: "icu_id"
  has_many   :old_rating_histories
  has_many   :old_tournaments, through: :old_rating_histories

  default_scope order("last_name, first_name")

  attr_accessible :first_name, :last_name, :email, :club, :address, :phone_numbers, :fed, :title, :gender, :note, :dob, :joined, :deceased, :master_id
  validates_presence_of     :first_name
  validates_presence_of     :last_name
  validates_format_of       :fed, with: /\A[A-Z]{3}\z/, allow_nil: true
  validates_format_of       :title, with: /\AW?[GIFCN]M\z/, allow_nil: true
  validates_format_of       :gender, with: /\A(M|F)\z/, allow_nil: true
  validates_inclusion_of    :deceased, in: [true, false]
  validates_numericality_of :master_id, only_integer: true, greater_than: 0, allow_nil: true
  validates_date            :dob, on_or_after: "1900-01-01", on_or_before: :today, allow_nil: true
  validates_date            :joined, on_or_after: "1960-01-01", on_or_before: :today, allow_nil: true

  def name(*args)
    args.push :reversed if args.empty?
    args[0] = :reversed if args.size == 1 && args.first == true
    args.shift if args.size == 1 && args.first == false
    name = args.include?(:reversed) ? "#{last_name}, #{first_name}" : "#{first_name} #{last_name}"
    more = args.inject([]) do |m, a|
      case a
      when :title then m.push title if title
      when :club  then m.push club  if club
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
 
  def age(at=nil)
    return nil unless dob
    at ||= Date.today
    return 0 if dob >= at
    at.year - dob.year - ((at.month > dob.month || (at.month == dob.month && at.day >= dob.day)) ? 0 : 1)
  end

  def self.search(params, path)
    matches = unscoped
    matches = matches.where(master_id: nil) unless params[:include_duplicates]
    matches = matches.where(deceased: false) unless params[:include_deceased]
    matches = matches.where(last_name_like(params[:last_name], params[:first_name])) if params[:last_name].present?
    matches = matches.where(first_name_like(params[:first_name], params[:last_name])) if params[:first_name].present?
    matches = matches.where(club: params[:club] == "None" ? nil : params[:club]) if params[:club].present?
    matches = matches.where("gender = 'M' OR gender IS NULL") if params[:gender] == "M"
    matches = matches.where("gender = 'F'") if params[:gender] == "F"
    matches = matches.where("title = ?", params[:title]) if params[:title].present?
    matches = matches.where("dob < ?", Time.now.years_ago(params[:min_age].to_i)) if params[:min_age].to_i > 0
    matches = matches.where("dob > ?", Time.now.years_ago(params[:max_age].to_i)) if params[:max_age].to_i > 0
    matches = matches.where("dob LIKE ?", "%#{params[:dob]}%") if params[:dob] && params[:dob].match(/^[-\d]+$/)
    matches = matches.where("id = ?", params[:id].to_i) if params[:id].to_i > 0
    matches = search_fed(matches, params[:fed])
    order = case params[:order]
    when "id"     then "id"
    when "update" then "updated_at DESC, id DESC"
    when "create" then "created_at DESC, id DESC"
    else               "last_name, first_name"
    end
    matches = matches.order(order)
    paginate(matches, path, params)
  end
  
  def self.search_fed(matches, fed)
    if fed.present?
      case fed
      when "???" then matches.where("fed IS NULL")
      when "IR?" then matches.where("fed IS NULL OR fed = 'IRL'")
      when "XXX" then matches.where("fed IS NOT NULL AND fed != 'IRL'")
      else matches.where("fed = ?", fed)
      end
    else
      matches
    end
  end
end
