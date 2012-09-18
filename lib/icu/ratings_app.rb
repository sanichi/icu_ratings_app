# encoding: UTF-8

module ICU
  module RatingsApp
    class Stats
      def self.provo_mismatches
        players = ::Player.includes(:tournament).where("tournaments.stage = 'rated'").where(old_full: false, category: "icu_player").where("new_games > old_games").includes(:results).order("players.id")
        bad, good = 0, 0
        mismatches = Hash.new
        players.each do |p|
          r1, g1 = p.old_rating, p.old_games
          r2, g2 = p.performance_rating, p.rateable_games
          if g1 == 0
            actual = r2.round
          else
            actual = ((r1 * g1 + r2 * g2) / (g1 + g2)).round
          end
          diff = (actual - p.new_rating).abs
          mismatches[diff] = Array.new unless mismatches[diff]
          mismatches[diff].push p.id
          if diff == 0
            good+= 1
          else
            bad+= 1
          end
        end
        puts "total: #{good + bad}"
        puts "matches: #{good}"
        puts "mismatches: #{bad}"
        mismatches.keys.sort.each do |diff|
          puts "#{'%-2d' % diff}: #{mismatches[diff].count} (#{mismatches[diff].examples})"
        end
      end
    end
  end
end
