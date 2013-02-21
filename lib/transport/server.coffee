{EventEmitter} = require 'events'
packets = require './packets'

class Server extends EventEmitter
  run: (port) ->
    return if @www

    @www = require('./www')()

    # handle emit request
    @www.all "/emit.json", (req, res) =>
      event = req.query.event
      data  = JSON.parse req.body.data

      packet = new packets.EmitPacket event, data, (err) ->
        res.writeHead 200, {}
        res.end()

      @emit 'emit', packet

    # handle ask request
    @www.all "/ask.json", (req, res) =>
      event = req.query.event
      data  = JSON.parse req.body.data

      packet = new packets.AskPacket event, data, (err, answer) ->
        res.json(answer)

      @emit 'ask', packet

    console.log("Listening on port: " + port)
    @www.listen port

module.exports = Server
