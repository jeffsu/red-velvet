StatisticalAggregator = require '../optimizer/statistical-aggregator'

INTERVAL = 1000
class WorkerHealth
  constructor: (@clientPool, @server) ->
    @process_rss   = new StatisticalAggregator()
    @delay_samples = new StatisticalAggregator()

    @startClientChecking()

  sendMetadata: ->
    process.send
      type: 'health'
      data: @getMetadata()
    
  getMetadata: ->
    clients:             @clientPool.getMetadata()
    server:              @server.getMetadata()
    process_rss_memory:  @process_rss.toJSON()
    event_latency:       @delay_samples.toJSON()
    server_profile:      @server.profile_data()
    client_profiles:     @clientPool.profile_data()

  startClientChecking: ->
    start = Date.now()
    check = =>
      now = Date.now()
      @delay_samples.push(now - start)
      start = now

      @process_rss.push(process.memoryUsage().rss)
      @sendMetadata()


    setInterval(check, INTERVAL)

module.exports = WorkerHealth
