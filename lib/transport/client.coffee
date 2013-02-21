request = require 'request'
RequestProfiler = require '../optimizer/request-profiler'

class Client
  constructor: (@host, @port) ->
    @base = "http://#{@host}:#{@port}"
    @profiler = new RequestProfiler()

  getMetaData: ->
    return {}

  # emit with no stringify
  emitStraight: (event, data, cb) ->
    params =
      uri: @base + "/emit.json"
      qs:
        event: event
      pool:
        maxSockets: 10
        event: event
      method: 'PUT'
      form:
        data: data

    profile = @profiler.start_timing(event, data.length)

    request params, (err, r, body) =>
      console.log 'emit: ' + event + ' finished'
      cb(err) if cb
      profile(err, body?.length)

  emit: (event, data, cb) ->
    @emitStraight event, JSON.stringify(data), cb

  ask: (question, data, cb) ->
    serialized = JSON.stringify(data)
    params =
      uri: @base + "/ask.json"
      pool:
        maxSockets: 10
      qs:
        question: question
      method: 'PUT'
      form:
        data: serialized

    profile = @profiler.start_timing(question, serialized.length)

    request params, (err, r, body) =>
      console.log 'response', question
      cb(err, JSON.parse(body)) if cb
      profile(err, body.length)

module.exports = Client
