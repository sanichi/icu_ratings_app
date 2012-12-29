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

      def self.bonus_mismatches
        players = ::Player.includes(:tournament).where("tournaments.stage = 'rated'")
        players = players.where(old_full: true, category: "icu_player").where("new_games > old_games + 4")
        players = players.where("k_factor IN (32, 40)").where("old_rating < 2100")
        players = players.includes(:results).order("players.id")
        bad, good, error = 0, 0, 0
        mismatches = Hash.new
        players.each do |p|
          bonus = 0
          if p.pre_bonus_rating && p.pre_bonus_performance
            if p.pre_bonus_rating < 2100
              threshold = p.old_rating + 32 + 3 * (p.new_games - p.old_games - 4)
              if p.pre_bonus_rating > threshold
                bonus = p.pre_bonus_rating - threshold
                bonus = (1.25 * bonus).round if p.k_factor == 40
                bonus_rating = p.pre_bonus_rating + bonus
                bonus_rating = p.pre_bonus_performance if bonus_rating > p.pre_bonus_performance
                bonus_rating = 2099 if bonus_rating > 2099
                bonus = bonus_rating - p.pre_bonus_rating
                bonus = 0 if bonus < 0
              end
            end
            if bonus == p.bonus
              good+= 1
            else
              bad+= 1
              diff = bonus - p.bonus
              mismatches[diff] = Array.new unless mismatches[diff]
              mismatches[diff].push p.id
            end
          else
            error+= 1
          end
        end
        puts "total: #{good + bad + error}"
        puts "matches: #{good}"
        puts "mismatches: #{bad}"
        puts "errors: #{error}"
        mismatches.keys.sort.each do |diff|
          puts "#{'%-3d' % diff}: #{mismatches[diff].count} (#{mismatches[diff].examples})"
        end
      end
    end
  end
end
