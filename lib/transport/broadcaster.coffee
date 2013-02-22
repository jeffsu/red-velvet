Client = require './client'
# for speaking directly to a worker
class Broadcaster
  constructor: (list) ->
    @clients = []

    for row in list
      host = row[0]
      port = row[1]

      @clients.push(new Client(host, port))
      
   emit: (event, data, cb) ->
     n = @clients.length
     onFin = (err) ->
       if --n <= 0
         cb(err) if cb
       
     json = JSON.stringify data
     @clients.forEach (client) ->
       client.emitStraight event, json, onFin

module.exports = Broadcaster
