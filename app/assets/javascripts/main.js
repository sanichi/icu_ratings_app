var DEFAULT_FADEIN_TIME = 1000;

$(function() {
  // Activate top menus.
  $("ul.sf-menu").superfish({cssArrows : false});

  // Fade out notices, but not completely. Leave alerts alone.
  $("div span.notice")
    .hover(
      function() {
        $(this).stop(true).animate({opacity : 1.0}, 1000);
      },
      function() {
        $(this).stop(true).animate({opacity : 0.0}, 1000);
      })
    .delay(7000)
    .animate({opacity : 0.0}, 3000);

  // Activate the help dialog and link or remove the link and it's parent.
  if ($("#help").dialog({autoOpen: false,  modal: false, title: "Help", width: 700}).size() == 0)
    $("#help-link").parent().hide();
  else
    $("#help-link,.help-link").on("click", function(event) {
      event.preventDefault();
      $("#help").dialog("open");
    });
});
