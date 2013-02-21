os = require 'os'

StatisticalAggregator = require '../optimizer/statistical-aggregator'

INTERVAL = 10000
config   = require '../config'

class ForemanHealth
  constructor: ->
    @load_average = new StatisticalAggregator()
    @free_memory  = new StatisticalAggregator()
    @host         = config.host
    @health       = {}
    @start()

  recordWorker: (port, health) ->
    @health[port] = health

  start: ->
    repeat = =>
      @load_average.push(os.loadavg()[0])       # always 1-minute average
      @free_memory.push(os.freemem())
      @health =
        free_memory:  @free_memory.toJSON()
        load_average: @load_average.toJSON()
      setTimeout(run, INTERVAL)

    run = =>
      @persister.saveHealth(@host, @health, repeat)

    run()

module.exports = ForemanHealth
