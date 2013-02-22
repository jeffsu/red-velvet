Client = require './client'

class Balancer
  constructor: ->
    @clients = []

  push: (client) ->
    @clients.push(client)
 
  choose:  ->
    @clients[Math.floor(Math.random()*@clients.length)]

  emit: (event, data, cb) ->
    @choose().emit(event, data, cb)

  ask: (question, data, cb) ->
    @choose().ask(question, data, cb)
    
  
module.exports = Balancer
