FactoryGirl.define do
  factory :rating_list do
    date                { Date.new(2012, 1,  1) }
    tournament_cut_off  { date.change(day: 15) }
    payment_cut_off     { date.end_of_month }
  end
end
