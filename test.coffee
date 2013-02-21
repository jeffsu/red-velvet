config = require './lib/config'
console.log config.host
config.checkController (err, isSelf) ->
  console.log isSelf
