class PagesController < ApplicationController
  def home
    @limit = 10
    @tournaments   = Tournament.latest(@limit)
    @articles      = Article.latest(@limit)
    @ratings_graph = IcuRatings::Graph.new(current_user, onload: true)
  end

  def contacts
    @contacts = User.contacts
  end

  def overview
    @overview = ::Pages::Overview.new
    authorize! :overview, ::Pages::Overview
  end

  def system_info
    @system_info = ::Pages::SystemInfo.new
    authorize! :system_info, ::Pages::SystemInfo
  end

  def not_found
    render file: "#{Rails.root}/public/404", layout: false, status: 404
  end
end
