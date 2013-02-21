index = require './index'

s = new index.Server()
s.run 3002

s.on 'emit', (packet) ->
  console.log 'got emit packet', packet.event
  packet.ack()

s.on 'ask', (packet) ->
  console.log 'got ask packet', packet
  packet.answer(null, "answer")

broadcaster = new index.Broadcaster([ [ 'localhost', 3002 ], [ 'localhost', 3002 ] ])
broadcaster.emit 'hello', 'world', ->
  console.log 'broadcast emitted'


c1 = new index.Client('localhost', 3002)
c2 = new index.Client('localhost', 3002)

cp = new index.ClientPool()

cp.add(c1, [ 'default' ])
cp.add(c2, [ 'default' ])

client = cp.choose('default')

client.emit 'hello', "world", (err) ->
  console.log 'got emit'

client.ask 'hello', "world", (err, answer) ->
  console.log 'got answer: ' + answer

setTimeout process.exit, 3000
