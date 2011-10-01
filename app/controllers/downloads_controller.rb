class DownloadsController < ApplicationController
  load_resource except: "index"
  authorize_resource

  def index
    @downloads = Download.search(params, downloads_path)
    render :results if request.xhr?
  end

  def show
    send_data(@download.data, filename: @download.file_name, type: @download.content_type)
  end

  def new
  end

  def edit
  end

  def create
    if params[:commit] == "Cancel"
      redirect_to downloads_path
    elsif @download.save
      redirect_to downloads_path, notice: "Download was successfully created."
    else
      render action: "new"
    end
  end

  def update
    if params[:commit] == "Cancel"
      redirect_to downloads_path
    elsif @download.update_attributes(params[:download])
      redirect_to downloads_path, notice: "Download was successfully updated."
    else
      render action: "edit"
    end
  end

  def destroy
    @download.destroy
    redirect_to downloads_path
  end
end
