FactoryGirl.define do
  factory :news_item do
    headline    { Faker::Lorem.sentence }
    story       { Faker::Lorem.paragraphs }
    published   true
    association :user
  end
end
