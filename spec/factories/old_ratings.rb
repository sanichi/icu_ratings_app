Factory.define :old_rating do |o|
  o.association  :icu_player
  o.rating       { rand(2400) }
  o.games        { rand(500) }
  o.full         true
end
