Factory.define :icu_rating do |r|
  r.association  :icu_player
  r.rating       { rand(2400) }
  r.list         "2011-09-01"
  r.full         true
end
