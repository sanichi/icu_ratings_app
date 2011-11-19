module Util
  module Pagination
    def paginate(matches, path, params, size=15)
      total = matches.count
      page = params[:page].to_i > 0 ? params[:page].to_i : 1
      per_page = params[:per_page].to_i > 0 ? params[:per_page].to_i : size
      page = 1 + count / per_page if page > 1 && (page - 1) * per_page >= count
      matches = matches.offset(per_page * (page - 1)) if page > 1
      matches = matches.limit(per_page)
      Paginator.new(matches, total, page, per_page, path, params)
    end
  end

  class Paginator
    attr_reader :count, :matches, :page, :per_page, :path, :params, :total

    def initialize(matches, total, page, per_page, path, params)
      @matches  = matches
      @count    = matches.count
      @total    = total
      @page     = page
      @per_page = per_page
      @path     = path
      @params   = params
    end

    def multi_page
      @total > @per_page
    end

    def before_end
      @page * @per_page < @total
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
      max = @total if @total < max
      min == max ? min.to_s : "#{min}-#{max}"
    end

    # Is this item the same as the one above (rows=0), the same as those following (rows>1) or different to both (row=1)?
    # Designed to support grouping of table rows that have the same value (see shared/_rowspan.html.haml).
    def rowspan(index, compare, content=nil)
      value = compare.call(@matches[index])
      return { rows: 0 } if index > 0 && value == compare.call(@matches[index-1])
      rows = 1
      (index+1..@count-1).each { |i| break unless value == compare.call(@matches[i]); rows += 1 }
      { rows: rows, content: (content ? content.call(@matches[index]) : value) }
    end

    private

    def adjacent_page(up)
      path + "?" + params.merge(page: page + (up ? 1 : -1), results: nil).to_query
    end
  end
end
