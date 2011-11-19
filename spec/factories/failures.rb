Factory.define :failure do |f|
  f.name     "RuntimeError"
  f.details  { Faker::Lorem.paragraphs }
end
