class NewsItem < ActiveRecord::Base
  extend ICU::Util::Pagination
  
  EXTENSIONS = { autolink: true, strikethrough: true, superscript: true, no_intra_emphasis: true }

  belongs_to :user
  before_validation :normalise_attributes

  validates_presence_of  :user_id, :headline, :story
  validates_inclusion_of :published, in: [true, false]

  def html_story
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, EXTENSIONS)
    markdown.render(story).html_safe
  end

  def self.search(params, path)
    matches = includes(user: :icu_player)
    order = params[:order].to_s.match(/^(created|updated)$/) ? params[:order] : "created"
    matches = matches.order("news_items.#{order}_at DESC")
    matches = matches.where("news_items.headline LIKE ?", "%#{params[:headline]}%") if params[:headline].present?
    matches = matches.where("news_items.story LIKE ?", "%#{params[:story]}%")       if params[:story].present?
    if params[:create]
      matches = matches.where(published: true)  if params[:published] == "true"
      matches = matches.where(published: false) if params[:published] == "false"
    else
      matches = matches.where(published: true)
    end
    paginate(matches, path, params)
  end

  # Latest news items for home page.
  def self.latest(limit=10)
    where(published: true).order("created_at DESC").limit(limit)
  end

  private

  def normalise_attributes
    self.published = true  if published == "true"
    self.published = false if published == "false"
  end
end
