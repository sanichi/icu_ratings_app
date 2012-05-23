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

  default_scope order("created_at DESC")

  def self.search(params, path)
    matches = scoped
    matches = matches.where("name LIKE ?", "%#{params[:name]}%") if params[:name].present?
    age = params[:age].to_i
    matches = matches.where("created_at > '#{age.days.ago.to_s(:db)}'") if age > 0
    paginate(matches, path, params)
  end

  def self.record(e, max=8)
    details = e.backtrace[0..max-1]
    details.unshift(e.message)
    create!(name: e.class.to_s, details: details.join("\n"))
  end
end
