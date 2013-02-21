Top = require './lib/top'

top = new Top()
top.node 'line-reader', (node) ->
  node.on 'line', (packet, app) ->
    console.log('got line: ' + packet.data)
    app.emit 'words', packet.data.split(/\s+/)
    packet.ack()

top.node 'words', (node) -> 
  node.on 'words', (packet, app) ->
    console.log('got words: ' + packet.data.join(', '))

app = top.getApp()
app.assume('line-reader')
app.assume('words')
app.unassume('words')
app.runServer(3002)

app.setClients [ [ 'localhost', 3002 ] ]

go = ->
  app.emit 'line', "hello world"
  app.emit 'words', "hello world".split(/\s+/)

setTimeout go, 1000
