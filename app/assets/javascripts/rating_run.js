// jQuery ->
//   if active() then start() else stop()
// 
// # count - number of polls
// # delay - seconds between polls
// # cron  - max seconds to keep polling in waiting state (should be slightly larger than cron delay)
// # max   - max seconds to keep polling in either state
// [count, delay, cron, max] = [0, 3, 70, 300]
// 
// schedule = ->
//   setTimeout(poll, delay * 1000)
// 
// poll = ->
//   if more() then schedule() else stop()
// 
// more = ->
//   args =
//     url: url()
//     async: false
//     dataType: 'json'
//     timeout: 1000 * (delay - 0.5)
//     error: -> abort()
//     success: (data) ->
//       $.each data, (key, val) ->
//         $("##{key}").text(val)
//   $.ajax args
//   count++
//   active()
// 
// active = ->
//   status = $("#status").text()
//   return false unless status == "waiting" || status == "processing"
//   return false if status == "waiting" && count * delay > cron
//   return false if count * delay > max
//   true
// 
// start = ->
//   $("#tictoc").show()
//   schedule()
// 
// stop = ->
//   $("#tictoc").hide()
// 
// abort = ->
//   $("#status").text("ajax error")
//   stop()
// 
// url = ->
//   "/admin/rating_runs/#{id()}.json"
// 
// id = ->
//   $("#status").data("id")

(function() {
  var abort, active, count, cron, delay, id, max, more, poll, schedule, start, stop, url, _ref;

  jQuery(function() {
    if (active()) {
      return start();
    } else {
      return stop();
    }
  });

  _ref = [0, 3, 70, 300], count = _ref[0], delay = _ref[1], cron = _ref[2], max = _ref[3];

  schedule = function() {
    return setTimeout(poll, delay * 1000);
  };

  poll = function() {
    if (more()) {
      return schedule();
    } else {
      return stop();
    }
  };

  more = function() {
    var args;
    args = {
      url: url(),
      async: false,
      dataType: 'json',
      timeout: 1000 * (delay - 0.5),
      error: function() {
        return abort();
      },
      success: function(data) {
        return $.each(data, function(key, val) {
          return $("#" + key).text(val);
        });
      }
    };
    $.ajax(args);
    count++;
    return active();
  };

  active = function() {
    var status;
    status = $("#status").text();
    if (!(status === "waiting" || status === "processing")) {
      return false;
    }
    if (status === "waiting" && count * delay > cron) {
      return false;
    }
    if (count * delay > max) {
      return false;
    }
    return true;
  };

  start = function() {
    $("#tictoc").show();
    return schedule();
  };

  stop = function() {
    return $("#tictoc").hide();
  };

  abort = function() {
    $("#status").text("ajax error");
    return stop();
  };

  url = function() {
    return "/admin/rating_runs/" + (id()) + ".json";
  };

  id = function() {
    return $("#status").data("id");
  };

}).call(this);
