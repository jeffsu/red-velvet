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

rv     = require '../lib'
layout = new rv.Layout()
  .role 'log-producer', (role) ->
    role.init (app) ->
      line = ->
        each_line LOG, (data) =>
          console.log 'emit: line'
          app.emit 'line', data
      ask = ->
        console.log 'asking average duration'
        apikey = null
        app.ask 'avg-duration', apikey, (err, answer) ->
          console.log answer

      setInterval ask, 3000

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
        duration:  row[14]
      app.emit 'log-data', data
      packet.ack()
  
  .role 'avg-duration', (role) ->
    counts = 0
    durations = 0
    role.on 'log-data', (packet, app) ->
      data = packet.data
      counts++
      duration += data.duration
      console.log 'counts', counts
      packet.ack()

    role.answer 'avg-duration', (packet, app) ->
      console.log 'got question'
      apikey = packet.data # TODO
      pakcet.answer null, counts ? 0 : durations/counts

module.exports = layout
