FactoryGirl.define do
  factory :failure do
    name     "RuntimeError"
    details  { Faker::Lorem.paragraphs }
  end
end
