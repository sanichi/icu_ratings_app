FactoryGirl.define do
  factory :subscription do
    icu_id    1350
    season    "2011-12"
    category  "online"
    pay_date  { Date.new(2011, 9, 1) }
  end
end
