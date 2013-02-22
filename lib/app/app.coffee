{EventEmitter} = require 'events'
RoleCollection = require './role-collection'

# You can think of this as an incarnation
# of a layout
class App extends EventEmitter
  constructor: ->
    @roles = {}
    @collections = {}
    @proxy = new AppProxy(this)

  assume: (role, part=0) ->
    name = role.name
    coll = (@collections[name] ||= new RoleCollection(role, @proxy))
    coll.assume(part)

  unassume: (role, part=0) ->
    # TODO

  handleEmit: (packet) ->
    for name, coll of @collections
      coll.emit(packet)

  handleAsk: (packet) ->
    for name, coll of @collections
      if coll.ask(packet)
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
