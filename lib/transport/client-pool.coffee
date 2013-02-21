Balancer = require './balancer'
Client   = require './client'
{EventEmitter} = require 'events'

class ClientPool extends EventEmitter
  constructor: ->
    @balancers = {}

  # [ [ host, port, [ ..roles.. ] ] ]
  setCluster: (data) ->
    for row in data
      @add(new Client(row[0], row[1]), row[2])
    @emit 'ready'

  add: (client, roles) ->
    for r in roles
      (@balancers[r] ||= new Balancer()).push(client)

  choose: (role) ->
    @balancers[role].choose()

module.exports = ClientPool
