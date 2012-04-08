module TournamentsHelper
  def player_id(player)
    "P-#{player.id}"
  end

  def player_class(player)
    "player P-#{player.id}"
  end

  def result_id(result)
    id = "R-#{result.round}-#{result.player_id}"
    id+= "-#{result.opponent_id}" if result.opponent_id
    id
  end

  def result_class(result)
    cls = %w[result centered]
    cls << result.colour if result.colour
    cls << "P-#{result.player_id}"
    cls << "P-#{result.opponent_id}" if result.opponent_id
    cls.join(" ")
  end
end
