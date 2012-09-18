namespace :stats do
  desc "List mismatches between calculated new ratings and the standard formulae for provisional ratings"
  task provo_mismatches: :environment do
    ICU::RatingsApp::Stats.provo_mismatches
  end
end
