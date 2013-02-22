{EventEmitter} = require 'events'

# You can think of this as an incarnation
# of a layout
class App extends EventEmitter
  constructor: ->
    @roles = {}
    @proxy = new AppProxy(this)

  assume: (role) ->
    @roles[role.name] = role
    role._init(@proxy)

  unassume: (role) ->
    delete @roles[role.name]

  handleEmit: (packet) ->
    event = packet.event
    for name, role of @roles
      if handler = role.ons[event]
        packet.count++
        handler(packet, @proxy)

  handleAsk: (packet) ->
    event = packet.event
    for name, role of @roles
      if handler = role.answers[event]
        handler(packet, @proxy)
        return

  migrate: (packet) ->
    @roles[packet.role].migrate_to(packet.to, packet)

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
