FactoryGirl.define do
  factory :user do
    email           { Faker::Internet.email }
    password        "password"
    salt            nil
    role            "member"
    status          "ok"
    expiry          Date.today.at_end_of_year
    association     :icu_player
    preferred_email nil
  end
end
