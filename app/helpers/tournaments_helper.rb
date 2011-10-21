module TournamentsHelper
  def player_id(player)
    "P-#{player.id}"
  end

  def player_class(player)
    "player P-#{player.id}"
  end

  def result_id(result)
    [result.player, result.opponent].inject("R-#{result.round}") do |id, p|
      id += "-#{p.id}" if p;
      id
    end
  end

  def result_class(result)
    cls = %w[result centered]
    cls << result.colour if result.colour
    [result.player, result.opponent].inject(cls.join(" ")) do |cl, p|
      cl += " P-#{p.id}" if p;
      cl
    end
  end
end
