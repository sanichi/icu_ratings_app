Factory.define :icu_rating do |r|
  r.association  :icu_player
  r.rating       { rand(2400) }
  r.list         { ((Date.today.year - 1 - rand(10)).to_s + %w(01 05 09)[rand(3)]).to_i }
  r.full         true
end

