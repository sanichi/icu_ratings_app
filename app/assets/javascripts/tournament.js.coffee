jQuery ->
  $(".player").hover (->
    hilite.player this, true
  ), ->
    hilite.player this, false

  $(".result").hover (->
    hilite.result this, true
  ), ->
    hilite.result this, false

hilite =
  player: (player, on_) ->
    p = player.id.split("-")
    selector = []
    if p.length is 2 and (p[0] is "P")
      items = [ ".P" ]
      $.each items, ->
        selector.push this + "-" + p[1]
    @toggle $(selector.join(", ")), on_

  result: (result, on_) ->
    p = result.id.split("-")
    selector = []
    if p[0] is "R"
      selector.push "#" + result.id
      selector.push "#P-" + p[2]
      if p.length is 4
        selector.push "#R-" + p[1] + "-" + p[3] + "-" + p[2]
        selector.push "#P-" + p[3]
    @toggle $(selector.join(", ")), on_

  toggle: (elements, on_) ->
    (if on_ then elements.addClass("hilite") else elements.removeClass("hilite"))
