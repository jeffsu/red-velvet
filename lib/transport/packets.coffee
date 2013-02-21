# data passed in to event handlers
class EmitPacket
  constructor: (@event, @data, @cb) ->
    @count  = 0
    @errors = []

  # TODO error handling
  ack: (err) ->
    @count--
    if @count <= 0
      @cb(err) if @cb

class AskPacket
  constructor: (@event, @data, @cb) ->

  answer: (err, data) ->
    @cb(err, data) if @cb


module.exports.AskPacket  = AskPacket
module.exports.EmitPacket = EmitPacket
