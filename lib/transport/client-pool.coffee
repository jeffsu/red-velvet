Balancer = require './balancer'
Client   = require './client'
{EventEmitter} = require 'events'

class ClientPool
  constructor: ->
    @balancers = {}
    @clients   = []

  getMetadata: ->
    return (c.getMetadata() for c in  @clients)

  profile_data: ->
    return (c.profile_data() for c in @clients)

  # [ 
  #   [ host, port, [ [ role, part ], [ role1 ] ] ]
  # ]
  setCluster: (data) ->
    for row in data
      host  = row[0]
      port  = row[1]
      roles = row[2]
      @add(new Client(host, port), roles)

  add: (client, roles) ->
    @clients.push(client)
    for r in roles
      role = r[0]
      part = r[1] || 0

      parts = @balancers[role] ||= []
      (parts[part] ||= new Balancer()).push(client)

  chooseBalancer: (role, data) ->
    part = role.getPartition(data)
    @balancers[role][part].choose()

  emit: (event, data, roles, cb) ->
    n = roles.length
    onFin = (err) ->
      if --n == 0
        cb(err) if cb
      
    for role in roles
      balancer = @chooseBalancer(role, data)
      balancer.emit(event, data, onFin)
  
  ask: (question, data, role, cb) ->
    balancer = @chooseBalancer(role, data)
    balancer.ask(question, data, cb)
    

module.exports = ClientPool
