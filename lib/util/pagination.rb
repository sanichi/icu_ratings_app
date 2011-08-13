module Util
  module Pagination
    def paginate(matches, path, params, size=15)
      count = matches.count
      page = params[:page].to_i > 0 ? params[:page].to_i : 1
      per_page = params[:per_page].to_i > 0 ? params[:per_page].to_i : size
      page = 1 + count / per_page if page > 1 && (page - 1) * per_page >= count
      matches = matches.offset(per_page * (page - 1)) if page > 1
      matches = matches.limit(per_page)
      Paginator.new(matches, count, page, per_page, path, params)
    end
  end

  class Paginator
    attr_reader :matches, :count, :page, :per_page, :path, :params

    def initialize(matches, count, page, per_page, path, params)
      @matches  = matches
      @count    = count
      @page     = page
      @per_page = per_page
      @path     = path
      @params   = params
    end

    def multi_page
      @count > @per_page
    end
    
    def before_end
      @page * @per_page < @count
    end

    def after_start
      @page > 1
    end
    
    def next_page
      adjacent_page(true)
    end
    
    def prev_page
      adjacent_page(false)
    end
    
    def sequence
      min = 1 + @per_page * (@page - 1)
      max = @per_page * @page
      max = @count if @count < max
      min == max ? min.to_s : "#{min}-#{max}"
    end
    
    private
    
    def adjacent_page(up)
      path + "?" + params.merge(:page => page + (up ? 1 : -1), :results => nil).to_query
    end
  end
end
