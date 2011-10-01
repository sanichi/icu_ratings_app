class NewsItemsController < ApplicationController
  load_resource except: "index"
  authorize_resource

  def index
    @news_items = NewsItem.search(params, news_items_path)
    render :results if request.xhr?
  end

  def show
    respond_to do |format|
      format.html
      format.text { render text: @news_item.story }
    end
  end

  def new
  end

  def edit
  end

  def create
    if params[:commit] == "Cancel"
      redirect_to news_items_path
    elsif @news_item.save
      redirect_to @news_item, notice: "News was successfully created."
    else
      render action: "new"
    end
  end

  def update
    if params[:commit] == "Cancel"
      redirect_to @news_item
    elsif @news_item.update_attributes(params[:news_item])
      redirect_to @news_item, notice: "News was successfully updated."
    else
      render action: "edit"
    end
  end

  def destroy
    @news_item.destroy
    redirect_to news_items_path
  end
end
