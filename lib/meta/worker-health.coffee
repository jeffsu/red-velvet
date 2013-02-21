os      = require 'os'
process = require 'process'

StatisticalAggregator = require '../optimizer/statistical-aggregator'

INTERVAL = 1000
class WorkerHealth
  constructor: (@clients) ->
    @free_memory   = new StatisticalAggregator()
    @process_rss   = new StatisticalAggregator()
    @delay_samples = new StatisticalAggregator()

    @startClientChecking()

  startClientChecking: ->
    start = Date.now()
    check = ->
      now = Date.now()
      @delay_samples.push(now - start)
      start = now

      @free_memory.push(os.freemem())
      @process_rss.push(process.memoryUsage().rss)
      process.send({ type: 'health',
                     data: {machine_free_memory: @free_memory.toJSON,
                            process_rss_memory:  @process_rss.toJSON
                            event_latency:       @delay_samples.toJSON }})

    setInterval(check, INTERVAL)

module.exports = WorkerHealth
