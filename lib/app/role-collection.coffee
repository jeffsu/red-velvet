Role = require './role'

# housing all the partitions for a given role
class RoleCollection
  constructor: (@first, @app) ->
    @name     = @first.name
    @roles    = [ @first ]
    @hash     = @first.hash
  
  getRole: (part, auto) ->
    if role = @roles[part]
      return role
    else if auto
      return @roles[part] = @copy()


  canEmit: (event) ->
    return @first.ons[event]

  canAnswer: (q) ->
    return @first.answers[q]

  emit: (packet) ->
    event = packet.event
    part  = packet.partition || 0

    if role = @getRole(part)
      if handler = role.ons[event]
        packet.count++
        handler(packet, @app)
        return true

    return false

  ask: (packet) ->
    event = packet.event
    part  = packet.partition || 0

    if role = @getRole(part)
      if handler = role.answers[event]
        handler(packet, @app)
        return true

    return false

  assume: (part) ->
    @getRole(part, true).assume(@app)

  copy: ->
    console.log 'COPY'
    new Role(@first.name, @first.options, @first.cb)

module.exports = RoleCollection
