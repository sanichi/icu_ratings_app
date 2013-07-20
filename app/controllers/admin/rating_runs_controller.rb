module Admin
  class RatingRunsController < ApplicationController
    authorize_resource

    def index
      @rating_runs = RatingRun.search(params, admin_rating_runs_path)
      render :results if request.xhr?
    end

    def show
      @rating_run = RatingRun.find(params[:id])
      render :json => @rating_run.to_json(only: [:status, :report], methods: :duration) if request.xhr?
    end

    def create
      @rating_run = RatingRun.new(rating_run_params(:start_tournament_id))
      @rating_run.user = current_user
      if @rating_run.save
        redirect_to [:admin, @rating_run], notice: "Run was successfully created."
      else
        logger.error(@rating_run.errors.full_messages.join("\n"))
        redirect_to admin_rating_runs_path
      end
    end

    def edit
      @rating_run = RatingRun.find(params[:id])
    end

    def update
      @rating_run = RatingRun.find(params[:id])
      @rating_run.update_attributes(rating_run_params(:reason))
    end

    def destroy
      @rating_run = RatingRun.find(params[:id])
      @rating_run.destroy
      redirect_to admin_rating_runs_path
    end

    private

    def rating_run_params(*list)
      params.require(:rating_run).permit(*list)
    end
  end
end
