http = require 'http'

LOG =
  host: 'dashboard.factual.com'
  path: '/logs?type=api-main&range=hours&date=2013-02-08&hour=04&minutes=&toHour=04&minutes='


each_line = (log, cb)->
  req = http.request log, (res) ->
    str = ''
    res.on 'data', (chunk) ->
      str += chunk.toString()
      until (idx = str.indexOf('\n')) == -1
        line = str.slice(0, idx)
        str  = str.slice(idx+1)
        cb(line)

    res.on 'end', () ->
      console.log 'done'

  req.end()

### poc
each_line LOG, (data) ->
  console.log data
###

{Layout} = require '../lib'
layout   = new Layout()
  .role 'log-producer', (role) ->
    role.init (app) ->
      each_line LOG, (data) =>
        app.emit 'line', data

      test_ask = ->
        console.log 'test asking average duration'
        apikey = 'every'
        app.ask 'avg-duration', apikey, (err, answer) ->
          console.log 'got answer:', answer

      setInterval test_ask, 3000

  .role 'log-reader', (role) ->
    role.on 'line', (packet, app) ->
      row  = packet.data.split('\t')
      data =
        timestamp: row[1]
        ip:        row[2]
        key:       row[3]
        view:      row[4]
        action:    row[6]
        query:     row[9]
        code:      row[12]
        duration:  row[15]
      app.emit 'log-data', data
      packet.ack()
  
  .role 'avg-duration', (role) ->
    counts = { every: 0 }
    durations = { every: 0 }
    role.on 'log-data', (packet, app) ->
      data = packet.data
      counts[data.key] ?= 0
      counts[data.key]++
      counts.every++

      durations[data.key] ?= 0
      durations[data.key] += parseInt(data.duration)
      durations.every += parseInt(data.duration)

      packet.ack()

    role.answer 'avg-duration', (packet, app) ->
      apikey = packet.data

      count = counts[apikey]
      duration = durations[apikey]

      answer = if count > 0 then duration/count else 0
      console.log count, duration
      console.log "question: #{apikey}, answer: #{answer}"
      packet.answer null, answer.toString()

module.exports = layout
