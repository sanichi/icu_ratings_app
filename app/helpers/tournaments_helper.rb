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
    [result.player, result.opponent].inject("result centered") do |id, p|
      id += " P-#{p.id}" if p;
      id
    end
  end
end
