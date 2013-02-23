{EventEmitter} = require 'events'
packets = require './packets'
config  = require '../config'

RequestProfiler = require '../optimizer/request-profiler'

class Server extends EventEmitter
  constructor: ->
    @profiler = new RequestProfiler()

  getMetadata: ->
    return {}

  profile_data: ->
    @profiler.toJSON()

  run: (port, app) ->
    return if @www

    @www = require('./www')()

    @www.get '/ask', (req, res) =>
      res.render 'worker-ask'

    @www.post '/ask/:question', (req, res) =>
      app.ask req.params.question, req.body.data, (err, answer) ->
        res.writeHead 200, {}
        res.write answer
        res.end()

    @www.post '/migrate', (req, res) =>
      role = req.query.role
      to   = req.query.to

      @emit 'migrate', new packets.MigratePacket role, to, (err) ->
        res.writeHead 200, {}
        res.end()

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

    console.log "listening on port #{port}"
    @www.listen port

module.exports = Server
