namespace :rating do
  desc "Perform a rating run"
  task run: :environment do
    ICU::RatingRun.new.rate_all
  end
end
