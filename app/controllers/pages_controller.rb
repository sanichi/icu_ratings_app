class PagesController < ApplicationController
  def home
    @limit = 10
    @tournaments = Tournament.latest(@limit)
    @articles = Article.latest(@limit)
  end

  def my_home
    authorize! :my_home, ::Pages::MyHome
    @icu_player = IcuPlayer.find_by_id(params[:id]) if params[:id]
    @icu_player ||= current_user.icu_player
    authorize! :show, @icu_player
    @my_home = ::Pages::MyHome.new(@icu_player.id)
  end

  def contacts
    @contacts = User.contacts
  end

  def overview
    authorize! :overview, ::Pages::Overview
    @overview = ::Pages::Overview.new
  end

  def system_info
    authorize! :system_info, ::Pages::SystemInfo
    @system_info = ::Pages::SystemInfo.new
  end

  def not_found
    render file: "#{Rails.root}/public/404", layout: false, status: 404
  end
end
