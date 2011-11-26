Factory.sequence(:fide_id) { |i| i }

Factory.define :fide_player do |p|
  p.association :icu_player
  p.id          { Factory.next(:fide_id) }
  p.first_name  { Faker::Name.first_name }
  p.last_name   { Faker::Name.last_name }
  p.fed         "IRL"
  p.gender      "M"
  p.born        nil
  p.title       nil
end
