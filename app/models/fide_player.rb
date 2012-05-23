# == Schema Information
#
# Table name: fide_players
#
#  id         :integer(4)      not null, primary key
#  last_name  :string(255)
#  first_name :string(255)
#  fed        :string(3)
#  title      :string(3)
#  gender     :string(1)
#  born       :integer(2)
#  rating     :integer(2)
#  icu_id     :integer(4)
#  created_at :datetime
#  updated_at :datetime
#

class FidePlayer < ActiveRecord::Base
  extend ICU::Util::Pagination
  extend ICU::Util::AlternativeNames

  has_many :fide_ratings, foreign_key: "fide_id", order: "list DESC", dependent: :destroy
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

  def icu_mismatches(icu_id)
    p = IcuPlayer.find_by_id(icu_id)
    m = []
    if p
      m.push "mismatched gender"              if gender && p.gender && gender != p.gender
      m.push "mismatched titles"              if title  && p.title  && title  != p.title
      m.push "mismatched federations"         if fed    && p.fed    && fed    != p.fed
      m.push "mismatched DOB and YOB"         if born   && p.dob    && born   != p.dob.year
      m.push "can't match a duplicate"        if p.master_id
      m.push "at least one name should match" if name_mismatches(p) == 2
    else
      m.push "no such ICU ID (icu_id)"
    end
    m.each { |x| errors.add :icu_id, x }
    m.size
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
    matches = matches.where("icu_id = ?", params[:icu_id].to_i) if params[:icu_id].to_i > 0
    matches = matches.where("icu_id IS #{params[:icu_match] == 'true' ? 'NOT' : ''} NULL") if params[:icu_match].present?
    paginate(matches, path, params)
  end

  private

  def name_mismatches(p)
    m = 0
    m+= 1 unless ICU::Name.new(first_name, "Smith").match(p.first_name, "Smith")
    m+= 1 unless ICU::Name.new("Johnny", last_name).match("Johnny", p.last_name)
    m
  end
end
