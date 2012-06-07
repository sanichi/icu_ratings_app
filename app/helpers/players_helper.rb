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
    ans = "#{ave} + 400 &times; (2 &times; #{scr} &minus; #{gms})"
    ans << " &divide; #{gms}" unless gms == 1
    ans.html_safe
  end

  def explain_full_change(player)
    ans = "(#{player.actual_score} &minus; #{round(player.expected_score)}) &times; #{player.k_factor}"
    ans << " + #{player.bonus}" unless player.bonus.to_i == 0
    ans.html_safe
  end

  def explain_full_rating(player)
    "#{player.old_rating} #{sign(player.rating_change, space: true)}".html_safe
  end

  def explain_full_games(player)
    "#{player.old_games} + #{player.rateable_games}".html_safe
  end

  def explain_provisional_rating(player)
    r1, g1 = player.old_rating, player.old_games
    r2, g2 = player.performance_rating, player.rateable_games
    "(#{r1} &times; #{g1} + #{round(r2, 1)} &times; #{g2}) &divide; (#{g1} + #{g2})".html_safe
  end

  def explain_provisional_change(player)
    "#{player.new_rating} &minus; #{player.old_rating}".html_safe
  end

  def explain_provisional_games(player)
    type = player.new_full ? "now full" : "still provisional"
    "#{player.old_games} + #{player.rateable_games} (rating is #{type})".html_safe
  end

  def explain_new_rating(player)
    explain_trn_rating(player)
  end

  def explain_new_games(player)
    type = player.new_full ? "full" : "provisional"
    "rating is #{type}"
  end
end
