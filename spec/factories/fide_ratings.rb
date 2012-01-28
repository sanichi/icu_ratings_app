Factory.define :fide_rating do |r|
  r.association  :fide_player
  r.rating       { 1 + rand(2500) }
  r.list         "2011-11-01"
  r.games        { rand(30) }
end
