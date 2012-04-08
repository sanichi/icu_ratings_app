FactoryGirl.define do
  factory :icu_player do
    sequence(:id) { |i| i }
    first_name    { Faker::Name.first_name }
    last_name     { Faker::Name.last_name }
    email         { Faker::Internet.email }
    club          nil
    address       nil
    phone_numbers nil
    fed           "IRL"
    title         nil
    joined        nil
    dob           nil
    gender        "M"
    deceased      false
    note          nil
    master_id     nil
  end
end
