FactoryGirl.define do
  factory :old_rating do
    icu_id       :icu_id
    rating       { rand(2400) }
    games        { rand(500) }
    full         true
  end
end
