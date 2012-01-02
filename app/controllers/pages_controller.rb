class PagesController < ApplicationController
  def home
    @limit = 10
    @tournaments   = Tournament.latest(@limit)
    @news_items    = NewsItem.latest(@limit)
    @ratings_graph = RatingsGraph.new(current_user, onload: true)
  end

  def contacts
    @contacts = User.contacts
  end

  def not_found
    render file: "#{Rails.root}/public/404.html", layout: false, status: 404
  end
end
