FactoryGirl.define do
  factory :fide_rating do
    association  :fide_player
    rating       { 1 + rand(2500) }
    list         "2011-11-01"
    games        { rand(30) }
  end
end
