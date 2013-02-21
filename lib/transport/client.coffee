request = require 'request'
RequestProfiler = require '../optimizer/request-profiler'

class Client
  constructor: (@host, @port) ->
    @base = "http://#{@host}:#{@port}"
    @profiler = new RequestProfiler()

  requestEmit: (event, data, cb) ->
    serialized = JSON.stringify(data)
    params =
      uri: @base + "/emit.json"
      qs:
        event: event
      pool:
        maxSockets: 10
        event: event
      method: 'PUT'
      form:
        data: serialized

    profile = @profiler.start_timing(event, serialized.length)

    request params, (err, r, body) =>
      console.log 'emit: ' + event + ' finished'
      cb(err) if cb
      profile(err, body.length)

  requestAsk: (event, data, cb) ->
    serialized = JSON.stringify(data)
    params =
      uri: @base + "/ask.json"
      pool:
        maxSockets: 10
      qs:
        event: event
      method: 'PUT'
      form:
        data: serialized

    profile = @profiler.start_timing(event, serialized.length)

    request params, (err, r, body) =>
      cb(err, JSON.parse(body)) if cb
      profile(err, body.length)

module.exports = Client
