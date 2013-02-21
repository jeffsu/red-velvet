index = require './index'
packets = require '../transport/packets'

layout = new index.Layout()

layout.role "line-producer", (role) ->
  role.init (app) ->
    line = -> app.emit "line", "words with friends"
    setInterval line, 100

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
  p = new packets.EmitPacket(event, data)
  app.handleEmit p

app.on 'ask', (event, data) ->
  console.log 'ask', event
  p = new packets.AskPacket(event, data)
  app.handleEmit p


app.assume layout.getRole("word-handler")
app.assume layout.getRole("line-handler")
app.assume layout.getRole("line-producer")
