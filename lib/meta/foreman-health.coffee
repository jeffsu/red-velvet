os = require 'os'

StatisticalAggregator = require '../optimizer/statistical-aggregator'

INTERVAL = 10000
config   = require '../config'

class ForemanHealth
  constructor: ->
    @free_memory = new StatisticalAggregator()
    @host   = config.host
    @health = {}
    @start()

  recordWorker: (port, health) ->
    @health[port] = health

  start: ->
    repeat = =>
      @free_memory.push(os.freemem())
      @health = {free_memory: @free_memory.toJSON}
      setTimeout(run, INTERVAL)

    run =>
      @persister.saveHealth(@host, @health, repeat)

    run()

module.exports = ForemanHealth
