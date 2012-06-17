function toggle_file_format() {
  var selected = this.value;
  toggle_upload_options(selected);
  toggle_help_sections(selected);
}
function toggle_upload_options(selected) {
  $.each(["name", "start", "finish", "feds", "ratings", "round_dates"], function(i, key) { toggle_upload_option(key, "off") });
  var on = [];
  switch(selected) {
    case "Krause":       on.push("feds", "ratings", "round_dates"); break;
    case "SwissPerfect": on.push("feds", "start", "finish"); break;
    case "SPExport":     on.push("feds", "start", "finish", "name"); break;
  }
  $.each(on, function(i, key) { toggle_upload_option(key, "on") })
}
function toggle_upload_option(key, status) {
  var div = $("#" + key).parent();
  status == "on" ? div.fadeIn(DEFAULT_FADEIN_TIME) : div.hide();
}
function toggle_help_sections(selected) {
  $("#upload_format option").each(function() { $("#help ." + this.value).hide() });
  $("#help ." + selected).show();
}
function check_form() {
  var errors = [];
  $.each({ "file" : "an upload file", "name" : "a tournament name", "start" : "a start date", "finish" : "an end date" }, function(key, val) {
    var input = $("#" + key);
    if (input.parent().css("display") != "none" && input[0].value == "") errors.push(val)
  });
  if (errors.length > 0) alert("Please provide: " + errors.join(", "))
  return errors.length > 0 ? false : true;
}
// Notes:
// 1. Using .on() instead of .bind() was necessary for the new_upload onsubmit behaviour to work in FireFox and IE.
// 2. Using coffescript didn't work in FireFox and IE (got the same syntax error as in note 1).
$(function() {
  $("#start").datepicker({ dateFormat: 'yy-mm-dd' });
  $("#finish").datepicker({ dateFormat: 'yy-mm-dd' });
  $("#upload_format").on("change", toggle_file_format).trigger("change")
  $("#new_upload").on("submit", check_form)
});
