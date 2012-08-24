# == Schema Information
#
# Table name: articles
#
#  id         :integer(4)      not null, primary key
#  headline   :string(255)
#  story      :text
#  published  :boolean(1)      default(FALSE)
#  user_id    :integer(4)
#  created_at :datetime
#  updated_at :datetime
#

class Article < ActiveRecord::Base
  extend ICU::Util::Pagination
  EXTENSIONS = { autolink: true, strikethrough: true, superscript: true, no_intra_emphasis: true }

  belongs_to :user

  attr_accessible :headline, :story, :published, :identity
  before_validation :normalise_attributes

  validates :user_id, :headline, :story, presence: true
  validates :published, inclusion: { in: [true, false] }
  validates :identity, length: { maximum: 32 }, uniqueness: true, allow_nil: true

  def html_story
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, EXTENSIONS)
    markdown.render(story).html_safe
  end

  def self.search(params, path)
    matches = includes(user: :icu_player)
    order = params[:order].to_s.match(/^(headline|created_at|updated_at)$/) ? params[:order] : "headline"
    order = "#{order} DESC" if order.match(/_at$/)
    matches = matches.order("articles.#{order}")
    matches = matches.where("articles.headline LIKE ?", "%#{params[:headline]}%") if params[:headline].present?
    matches = matches.where("articles.identity LIKE ?", "%#{params[:identity]}%") if params[:identity].present?
    matches = matches.where("articles.story LIKE ?", "%#{params[:story]}%")       if params[:story].present?
    if params[:create]
      matches = matches.where(published: true)  if params[:published] == "true"
      matches = matches.where(published: false) if params[:published] == "false"
    else
      matches = matches.where(published: true)
    end
    paginate(matches, path, params)
  end

  def self.get_by_identity(identity)
    find_by_identity_and_published(identity, true)
  end

  # Latest articles for home page.
  def self.latest(limit=10)
    where(published: true).order("updated_at DESC").limit(limit)
  end

  private

  def normalise_attributes
    self.published = true  if published == "true"
    self.published = false if published == "false"
    self.identity  = nil   if identity.blank?

    # After the upgrade to 3.2.3, spurious newlines started to appear pre-pended to the story.
    # In the release notes for 3.2.3, there's mention of adding a new line after textareas.
    # And for some reason, story is sometimes an Array in spec/requests/articles_spec.rb
    # which I don't understand at all but which explains the condition below.
    self.story = story.sub(/^\n/, '') if story.is_a?(String)
  end
end
