# == Schema Information
#
# Table name: uploads
#
#  id            :integer(4)      not null, primary key
#  name          :string(255)
#  format        :string(255)
#  content_type  :string(255)
#  file_type     :string(255)
#  size          :integer(4)
#  tournament_id :integer(4)
#  user_id       :integer(4)
#  error         :text
#  created_at    :datetime
#

class Upload < ActiveRecord::Base
  extend ICU::Util::Pagination
  include ICU::Util::Model

  FORMATS = [['Swiss Perfect', 'SwissPerfect'], ['Swiss Perfect Export', 'SPExport'], ['FIDE-Krause', 'Krause'], ['ICU-CSV', 'ForeignCSV']]
  DEFAULT_FORMAT = 'SwissPerfect'

  belongs_to :tournament
  belongs_to :user

  validates_inclusion_of    :format, in: FORMATS.map(&:last)
  validates_presence_of     :file_type, :content_type
  validates_numericality_of :size, only_integer: true, greater_than: 0
  validates_numericality_of :user_id, only_integer: true, greater_than: 0, message: "(%{value}) is invalid"

  # Extract (parse) an ICU::Tournament from an uploaded file and then build a Tournament from that.
  def extract(params, user_id)
    file = params[:file]
    return if file.blank?
    self.size = file.size
    return if size == 0
    self.name = base_part_of(file.original_filename)
    self.content_type = file.content_type
    self.file_type = %x{file -b #{file.tempfile.path}}.chomp

    opts = {}
    case format
    when "SwissPerfect"
      opts[:zip]   = true
      opts[:start] = params[:start]
      opts[:fed]   = params[:feds] if params[:feds].match(/^(skip|ignore)$/)
    when "SPExport"
      opts[:name]  = params[:name]
      opts[:start] = params[:start]
    when "Krause"
      opts[:fide]        = params[:ratings] == "FIDE"
      opts[:fed]         = params[:feds] if params[:feds].match(/^(skip|ignore)$/)
      opts[:round_dates] = params[:round_dates] if params[:round_dates] == "ignore"
    end

    begin
      icut = ICU::Tournament.parse_file!(file.tempfile.path, format, opts)
      icut.finish = params[:finish] if format.match(/^(SwissPerfect|SPExport)$/) && params[:finish].match(/^\d\d\d\d-\d\d-\d\d$/)
      icut.renumber(:name)
      tournament  = Tournament.build_from_icut(icut, self)
      tournament.user_id = user_id
    rescue Exception => e
      self.error = e.message
    end

    tournament
  end

  # Search and paginate.
  def self.search(params, path)
    matches = includes(:tournament)
    matches = matches.where("uploads.name LIKE ?", "%#{params[:name]}%") if params[:name].present?
    matches = matches.where("uploads.created_at LIKE ?", "%#{params[:created_at]}%") if params[:created_at].present?
    matches = matches.where(format: params[:format]) if params[:format].present?
    matches = matches.where(user_id: params[:user_id].to_i) if params[:user_id].to_i > 0
    matches = matches.order(created_at: :desc)
    paginate(matches, path, params)
  end
end
