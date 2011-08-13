$(function() {
  $('.player').hover(function() { hilite.player(this, true) }, function() { hilite.player(this, false) });
  $('.result').hover(function() { hilite.result(this, true) }, function() { hilite.result(this, false) });
});

var hilite = {
  player: function(player, on) {
    var p = player.id.split('-');  // P-player
    var selector = [];
    if (p.length == 2 && (p[0] == 'P'))
    {
      var items = ['.P'];  // just highlight results
      $.each(items, function() { selector.push(this + '-'  + p[1]) });
    }
    this.toggle($(selector.join(', ')), on);
  },
  result: function(result, on) {
    var p = result.id.split('-');  // R-round-player-opponent or, for a bye, R-round-player
    var selector = []
    if (p[0] == 'R') {
      selector.push('#' + result.id)  // the result
      selector.push('#P-' + p[2])     // the player
      if (p.length == 4) {
        selector.push('#R-' + p[1] + '-' + p[3] + '-' + p[2])  // the opposite result
        selector.push('#P-' + p[3])                            // the opponent
      }
    }
    this.toggle($(selector.join(', ')), on);
  },
  toggle: function(elements, on) {
    on ? elements.addClass('hilite') : elements.removeClass('hilite');
  }
};
