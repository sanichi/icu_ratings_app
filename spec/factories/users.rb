Factory.define :user do |u|
  u.email           { Faker::Internet.email }
  u.password        "password"
  u.role            "member"
  u.expiry          Date.today.at_end_of_year
  u.association     :icu_player
  u.preferred_email nil
end
