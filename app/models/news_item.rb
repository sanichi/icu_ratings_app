class NewsItem < ActiveRecord::Base
  extend Util::Pagination

  belongs_to :user
  validates_presence_of :user_id, :headline, :story

  def html_story
    Redcarpet.new(story).to_html.html_safe
  end

  def self.search(params, path)
    params[:order] = "created" unless params[:order].to_s.match(/\A(created|updated)\Z/)
    matches = includes(user: :icu_player)
    matches = matches.order("news_items.#{params[:order]}_at DESC")
    matches = matches.where("headline LIKE ?", "%#{params[:headline]}%") unless params[:headline].blank?
    matches = matches.where("story LIKE ?", "%#{params[:story]}%") unless params[:story].blank?
    paginate(matches, path, params)
  end

  def self.latest(limit=10)
    order("created_at DESC").limit(limit)
  end
end
