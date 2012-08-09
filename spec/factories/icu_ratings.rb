FactoryGirl.define do
  factory :icu_rating do
    association      :icu_player
    rating           { 1 + rand(2400) }
    list             "2011-09-01"
    full             true
    original_rating  { rating + (rand(3) - 1) * rand(20) }
    original_full    true
  end
end
