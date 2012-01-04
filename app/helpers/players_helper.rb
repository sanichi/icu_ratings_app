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
end
