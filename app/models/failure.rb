class Failure < ActiveRecord::Base
  extend Util::Pagination

  default_scope order("created_at DESC")

  def self.search(params, path)
    matches = Failure.scoped
    matches = matches.where("name LIKE ?", "%#{params[:name]}%") if params[:name].present?
    age = params[:age].to_i
    matches = matches.where("created_at > '#{age.days.ago.to_s(:db)}'") if age > 0
    paginate(matches, path, params)
  end
end
