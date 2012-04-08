class Event < ActiveRecord::Base
  extend ICU::Util::Pagination

  default_scope order("created_at DESC")

  def self.search(params, path)
    matches = scoped
    matches = matches.where("name LIKE ?", "%#{params[:name]}%") unless params[:name].blank?
    matches = matches.where("report LIKE ?", "%#{params[:report]}%") unless params[:report].blank?
    matches = matches.where("success = ?", params[:success]) unless params[:success].blank?
    matches = matches.where("time >= ?", params[:min_time].to_i) if params[:min_time].to_i > 0
    matches = matches.where("time <= ?", params[:max_time].to_i) if params[:max_time].to_i > 0
    paginate(matches, path, params)
  end
end
