{EventEmitter} = require 'events'
packets = require './packets'

RequestProfiler = require '../optimizer/request-profiler'

class Server extends EventEmitter
  constructor:
    @profiler = new RequestProfiler()

  run: (port) ->
    return if @www

    @www = require('./www')()

    # handle emit request
    @www.all "/emit.json", (req, res) =>
      event   = req.query.event
      data    = JSON.parse req.body.data

      profile = @profiler.start_timing(event, req.body.data.length)
      packet  = new packets.EmitPacket event, data, (err) ->
        profile(err, 0)                 # reply is empty
        res.writeHead 200, {}
        res.end()

      @emit 'emit', packet

    # handle ask request
    @www.all "/ask.json", (req, res) =>
      question = req.query.question
      data     = JSON.parse req.body.data

      profile = @profiler.start_timing(question, req.body.data.length)
      packet  = new packets.AskPacket question, data, (err, answer) ->
        serialized = JSON.stringify(answer)
        profile(err, serialized.length)
        res.writeHead 200, {'content-type': 'text/json'}
        res.end(serialized, 'utf8')

      @emit 'ask', packet

    console.log("Listening on port: " + port)
    @www.listen port

module.exports = Server
