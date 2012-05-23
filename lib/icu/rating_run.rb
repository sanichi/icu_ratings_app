module ICU
  class RatingRun
    Error = Class.new(StandardError)

    def rate_all
      get_flag
      get_rating_run
      check_rating_run
      start_rating_run
    rescue => e
      @error = e
    ensure
      clean_up
    end

    private

    # Check there's a flag for our environment.
    def get_flag
      @flag = ::RatingRun.flag(true)
      begin
        @id = File.open(@flag) { |f| f.read }
      rescue
        raise Error.new("no flag (#{@flag}) found")
      end
      raise Error.new("no ID in flag (#{@id})") unless @id.match(/^[1-9]\d*$/)
      @id = @id.to_i
      File.unlink(@flag)
      raise Error.new("unable to delete flag") if File.exists?(@flag)
    end

    # Get the RatingRun object corresponding to the ID found in the flag file.
    def get_rating_run
      begin
        @rating_run = ::RatingRun.find(@id)
      rescue ActiveRecord::RecordNotFound => e
        raise Error.new("no object corresponfing to ID found")
      end
    end

    # Sanity check the rating run instance.
    def check_rating_run
      raise Error.new("rating run is not in waiting state") unless @rating_run.status == "waiting"
      rivals = @rating_run.rivals
      raise Error.new("there are other unfinished runs (#{rivals.map(&:id).join(', ')})") if rivals.count != 0
    end

    # Start the rating run.
    def start_rating_run
      @rating_run.process
    end

    # Create a Failure to record any error.
    def clean_up
      return unless @error
      if @rating_run
        @rating_run.add("Error: #{@error.message}", false)
        @rating_run.finish(false)
      end
      Failure.record(@error)
    end
  end
end
