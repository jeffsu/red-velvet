{EventEmitter} = require 'events'

# You can think of this as an incarnation
# of a layout
class App extends EventEmitter
  constructor: ->
    @roles = []
    @proxy = new AppProxy(this)

  assume: (role) ->
    @roles.push role
    role._init(@proxy)

  unassume: (role) ->
    @roles = @roles.filter (r) ->
      r.name != role.name
  
  handleEmit: (packet) ->
    event = packet.event
    for role in @roles
      if handler = role.ons[event]
        packet.count++
        handler(packet, @proxy)

  handleAsk: (packet) ->
    event = packet.event
    for role in @roles
      if handler = role.answers[event]
        handler(packet, @proxy)
        return

  _emit: (event, data) ->
    # I know, weird but we want to 
    # "capture" meta level emit events
    # called from the application
    @emit 'emit', event, data

  # TODO
  ask: (question, data, cb) ->
    @emit 'ask', question, data, cb
    
# this is what everyone sees in 
# their actual code
class AppProxy
  constructor: (@app) ->

  emit: (event, data) ->
    @app._emit(event, data)

  ask: (question, data, cb) ->
    @app.ask(question, data, cb)
    
module.exports = App
