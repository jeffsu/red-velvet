INTERVAL = 10000

class ForemanHealth
  constructor: (@host, @persister) ->
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
