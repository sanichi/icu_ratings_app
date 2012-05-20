FactoryGirl.define do
  factory :article do
    headline    { Faker::Lorem.sentence }
    story       { Faker::Lorem.paragraphs }
    published   true
    association :user
  end
end
