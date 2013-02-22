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
        row  = line.split('\t')
        data =
          timestamp: row[1]
          ip:        row[2]
          key:       row[3]
          view:      row[4]
          action:    row[6]
          query:     row[9]
          code:      row[12]
          duration:  row[14]
        cb(data)

    res.on 'end', () ->
      console.log 'done'

  req.end()

### poc
each_line LOG, (data) ->
  console.log data
###

rv   = require '../lib'
new rv.Layout()
  .role 'log-reader', (role) ->
    role.init (app) ->
      line: (packet, app) ->
        each_line LOG, (data) =>
          app.emit 'line', data
          packet.ack()
