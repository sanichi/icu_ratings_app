FactoryGirl.define do
  factory :download do
    comment      { Faker::Lorem.sentence.truncate(80) }
    data         { Faker::Lorem.paragraphs }
    file_name    { Faker::Lorem.words(1).first + ".txt" }
    content_type "text/plain"
  end
end