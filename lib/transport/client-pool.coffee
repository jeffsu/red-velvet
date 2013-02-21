Balancer = require './balancer'
Client   = require './client'
{EventEmitter} = require 'events'

class ClientPool
  constructor: ->
    @balancers = {}
    @clients   = []

  getMetaData: ->
    return @clients.map (c) -> c.getMetaData() 

  # [ [ host, port, [ ..roles.. ] ] ]
  setCluster: (data) ->
    for row in data
      @add(new Client(row[0], row[1]), row[2])

  add: (client, roles) ->
    @clients.push(client)
    for r in roles
      (@balancers[r] ||= new Balancer()).push(client)

  choose: (role) ->
    @balancers[role].choose()

  emit: (event, data, roles, cb) ->
    n = roles.length
    onFin = (err) ->
      if --n == 0
        cb(err) if cb
      
    for role in roles
      client = @balancers[role].choose()
      client.emit(event, data, onFin)
    
  
  ask: (question, data, role, cb) ->
    client = @balancers[role].choose()
    client.ask(question, data, cb)
    

module.exports = ClientPool
