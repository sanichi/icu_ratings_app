class PagesController < ApplicationController
  def home
    @limit = 10
    @tournaments = Tournament.latest(@limit)
    @articles = Article.latest(@limit)
  end

  def my_home
    authorize! :my_home, ::Pages::MyHome
    @icu_player = current_user.icu_player
    @my_home = ::Pages::MyHome.new(@icu_player.id)
  end

  def their_home
    authorize! :their_home, ::Pages::MyHome
    @icu_player = IcuPlayer.find(params[:id])
    @my_home = ::Pages::MyHome.new(@icu_player.id)
    render "my_home"
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
    render file: "#{Rails.root}/public/404", formats: [:html], layout: false, status: 404
  end
end
