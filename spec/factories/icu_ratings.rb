FactoryGirl.define do
  factory :icu_rating do
    association  :icu_player
    rating       { 1 + rand(2400) }
    list         "2011-09-01"
    full         true
  end
end
