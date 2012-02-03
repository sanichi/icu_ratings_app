class FederationsController < ApplicationController
  def index
    match = (params[:match] || "").downcase.strip
    @federations = ICU::Federation.menu(order: params[:order]).find_all do |f|
      match.length == 0 || f.first.downcase.index(match) || f.last.downcase.index(match)
    end
    render :results if request.xhr?
  end
end
