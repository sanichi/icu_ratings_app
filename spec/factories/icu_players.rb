Factory.sequence(:icu_id) { |i| i }

Factory.define :icu_player do |p|
  p.id            { Factory.next(:icu_id) }
  p.first_name    { Faker::Name.first_name }
  p.last_name     { Faker::Name.last_name }
  p.email         { Faker::Internet.email }
  p.club          nil
  p.address       nil
  p.phone_numbers nil
  p.fed           "IRL"
  p.title         nil
  p.joined        { Date.today - 365 * rand(35) }
  p.dob           { joined - 365 * (10 + rand(50)) }
  p.gender        "M"
  p.deceased      false
  p.note          nil
  p.master_id     nil
end
