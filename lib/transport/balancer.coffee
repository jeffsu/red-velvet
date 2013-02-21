Client = require './client'
class Balancer
  constructor: ->
    @clients = []

  push: (client) ->
    @clients.push(client)
 
  choose: ->
    @clients[Math.floor(Math.random()*@clients.length)]
  
module.exports = Balancer
