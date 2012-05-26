jQuery ->
  if active() then start() else stop()

# count - number of polls
# delay - seconds between polls
# cron  - max seconds to keep polling in waiting state (should be slightly larger than cron delay)
# max   - max seconds to keep polling in either state
[count, delay, cron, max] = [0, 3, 70, 300]

schedule = ->
  setTimeout(poll, delay * 1000)

poll = ->
  if more() then schedule() else stop()

more = ->
  args =
    url: url()
    dataType: 'json'
    error: -> abort()
    success: (data) ->
      $.each data, (key, val) ->
        $("##{key}").text(val)
  $.ajax args
  count++
  active()

active = ->
  status = $("#status").text()
  return false unless status == "waiting" || status == "processing"
  return false if status == "waiting" && count * delay > cron
  return false if count * delay > max
  true

start = ->
  $("#tictoc").show()
  schedule()

stop = ->
  $("#tictoc").hide()

abort = ->
  $("#status").text("ajax error")
  stop()

url = ->
  "/admin/rating_runs/#{id()}.json"

id = ->
  $("#status").data("id")
