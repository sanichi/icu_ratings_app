namespace :stats do
  desc "List mismatches between calculated new ratings and the standard formulae for provisional ratings"
  task provo_mismatches: :environment do
    ICU::RatingsApp::Stats.provo_mismatches
  end

  desc "List players that look as if they should have got a bonus but didn't"
  task bonus_mismatches: :environment do
    ICU::RatingsApp::Stats.bonus_mismatches
  end
end
