# == Schema Information
#
# Table name: failures
#
#  id         :integer(4)      not null, primary key
#  name       :string(255)
#  details    :text
#  created_at :datetime
#

class Failure < ActiveRecord::Base
  extend ICU::Util::Pagination

  IGNORE = %w[ActiveRecord::RecordNotFound ActionController::UnknownFormat]

  default_scope -> { order(created_at: :desc) }

  before_create :normalize_details

  def self.search(params, path)
    matches = all
    matches = matches.where("name LIKE ?", "%#{params[:name]}%") if params[:name].present?
    age = params[:age].to_i
    matches = matches.where("created_at > '#{age.days.ago.to_s(:db)}'") if age > 0
    paginate(matches, path, params)
  end

  def self.record(e, max=8)
    details = e.backtrace ? e.backtrace[0..max-1] : []
    details.unshift(e.message)
    create!(name: e.class.to_s, details: details.join("\n"))
  end

  def self.examine(payload)
    name = payload[:exception].first
    unless IGNORE.include?(name)
      Failure.create!(name: name, details: payload.dup)
    end
  end

  private

  def normalize_details
    if details.is_a?(Hash)
      if details[:exception].is_a?(Array) && details[:exception].size == 2
        exception = details.delete(:exception)
        details[:name] = exception.first
        details[:message] = exception.last
      end
      self.details = details.map{ |key,val| "#{key}: #{val}" }.sort.join("\n")
    end
  end
end
