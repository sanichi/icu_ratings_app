Factory.define :download do |d|
  d.comment      { Faker::Lorem.sentence }
  d.data         { Faker::Lorem.paragraphs }
  d.file_name    { Faker::Lorem.words(1).first + ".txt" }
  d.content_type "text/plain"
end