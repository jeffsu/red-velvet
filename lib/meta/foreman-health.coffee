os = require 'os'

StatisticalAggregator = require '../optimizer/statistical-aggregator'

INTERVAL = 10000
config   = require '../config'

class ForemanHealth
  constructor: (@foreman) ->
    @load_average = new StatisticalAggregator()
    @free_memory  = new StatisticalAggregator()
    @host         = config.host
    @health       = {}
    @grid         = config.grid
    @start()

  start: ->
    repeat = =>
      @load_average.push(os.loadavg()[0])       # always 1-minute average
      @free_memory.push(os.freemem())

      total = 0
      total++ for w of @foreman.workers

      @health =
        free_memory:  @free_memory.toJSON()
        load_average: @load_average.toJSON()
        worker_size:  total
        cpus:         os.cpus()
      @grid.write @host, config.port, 'health', JSON.stringify @health

    setInterval(repeat, INTERVAL)

module.exports = ForemanHealth
