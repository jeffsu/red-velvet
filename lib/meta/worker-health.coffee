process = require 'process'

StatisticalAggregator = require '../optimizer/statistical-aggregator'

INTERVAL = 1000
class WorkerHealth
  constructor: (@clientPool, @server) ->
    @process_rss   = new StatisticalAggregator()
    @delay_samples = new StatisticalAggregator()

    @startClientChecking()

  sendMetaData: ->
    process.send({ type: 'health', data: @getMetaData() })
    
  getMetaData: ->
    return
      clients:             @clientPool.getMetaData
      #server:              @server.getMetaData
      process_rss_memory:  @process_rss.toJSON
      event_latency:       @delay_samples.toJSON



  startClientChecking: ->
    start = Date.now()
    check = =>
      now = Date.now()
      @delay_samples.push(now - start)
      start = now

      @process_rss.push(process.memoryUsage().rss)
      @sendMetaData()


    setInterval(check, INTERVAL)

module.exports = WorkerHealth
