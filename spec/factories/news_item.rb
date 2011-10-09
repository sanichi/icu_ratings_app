Factory.define :news_item do |n|
  n.headline    { Faker::Lorem.sentence }
  n.story       { Faker::Lorem.paragraphs }
  n.association :user
end
