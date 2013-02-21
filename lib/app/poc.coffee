index = require './index'
Packet = require '../transport/packet'

layout = new index.Layout()

layout.role "line-producer", (role) ->
  role.init (app) ->
    app.emit "line", "words with friends"

layout.role "line-handler", (role) ->
  role.on "line", (packet, app) ->
    app.emit "words", packet.data.split(/\s+/)
    packet.ack()

layout.role "word-handler", (role) ->
  role.on "words", (packet, app) ->
    console.log "got words: ", packet.data
  
app = new index.App()

app.on 'emit', (event, data) ->
  console.log 'emit', event
  p = new Packet(event, data)
  app.handlePacket p

app.assume layout.getRole("word-handler")
app.assume layout.getRole("line-handler")
app.assume layout.getRole("line-producer")
