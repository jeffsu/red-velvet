request = require 'request'
class Client
  constructor: (@host, @port) ->
    @base = "http://#{@host}:#{@port}"
    @stats = { count: 0, totalTime: 0, errors: 0, outstanding: 0 }

  requestEmit: (event, data, cb) ->
    params =
      uri: @base + "/emit.json"
      qs:
        event: event
      pool:
        maxSockets: 10
        event: event
      method: 'PUT'
      form:
        data: JSON.stringify(data)


    start = Date.now()
    @stats.outstanding++

    request params, (err, r, body) =>
      console.log 'emit: ' + event + ' finished'
      cb(err) if cb
      @stats.count++
      @stats.outstanding--
      @stats.errors++
      @stats.totalTime += start - Date.now()

  requestAsk: (event, data, cb) ->
    params =
      uri: @base + "/ask.json"
      pool:
        maxSockets: 10
      qs:
        event: event
      method: 'PUT'
      form:
        data: JSON.stringify(data)

    start = Date.now()
    @stats.outstanding++

    request params, (err, r, body) =>
      cb(err, JSON.parse(body)) if cb
      @stats.count++
      @stats.outstanding--
      @stats.errors++
      @stats.totalTime += start - Date.now()


  
module.exports = Client
