namespace :export do
  desc "Export the lastest ratings in various formats"
  task ratings: :environment do
    ICU::Export::ratings
  end
end