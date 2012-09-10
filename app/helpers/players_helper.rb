# encoding: UTF-8

module PlayersHelper
  def category_icon(player)
    if player.status_ok?
      image = case player.category
              when "icu_player"     then "user_green"
              when "foreign_player" then "user_blue"
              when "new_player"     then "user_orange"
              else "user_red"  # shouldn't happen
              end
      alt = player.category.present? ? t(player.category) : "Unknown"
    else
      image = "flag_red"
      alt = "Problem"
    end
    icon_tag image, alt
  end

  def explain_trn_rating(player)
    ave = round(player.ave_opp_rating, 1)
    gms = player.rateable_games
    scr = round(player.rateable_score, 1)
    ans = "#{ave} + 400 × (2 × #{scr} − #{gms})"
    ans << " ÷ #{gms}" unless gms == 1
    ans
  end

  def explain_full_change(player)
    ans = "(#{player.actual_score} − #{round(player.expected_score)}) × #{player.k_factor}"
    ans << " + #{player.bonus}" unless player.bonus.to_i == 0
    ans
  end

  def explain_full_rating(player)
    "#{player.old_rating} #{sign(player.rating_change, space: true)}"
  end

  def explain_full_games(player)
    "#{player.old_games} + #{player.rateable_games}"
  end

  def explain_provisional_rating(player)
    r1, g1 = player.old_rating, player.old_games
    r2, g2 = player.performance_rating, player.rateable_games
    "(#{r1} × #{g1} + #{round(r2, 1)} × #{g2}) ÷ (#{g1} + #{g2})"
  end

  def explain_provisional_change(player)
    "#{player.new_rating} − #{player.old_rating}"
  end

  def explain_provisional_games(player)
    type = player.new_full ? "now full" : "still provisional"
    "#{player.old_games} + #{player.rateable_games} (rating is #{type})"
  end

  def explain_new_rating(player)
    explain_trn_rating(player)
  end

  def explain_new_games(player)
    type = player.new_full ? "full" : "provisional"
    "rating is #{type}"
  end
end
