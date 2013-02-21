INTERVAL = 10000
config   = require '../config'

class ForemanHealth
  constructor: ->
    @host   = config.host
    @health = {}
    @start()
    
  recordWorker: (port, health) ->
    @health[port] = health

  start: ->
    repeat = =>
      @health = {}
      setTimeout(run, INTERVAL)

    run =>
      @persister.saveHealth(@host, @health, repeat)

    run()

module.exports = ForemanHealth
