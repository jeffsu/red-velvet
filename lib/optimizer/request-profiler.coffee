# Request profilers collect statistics per request type. Each client (which
# itself is parameterized by the destination) owns a request profiler to
# describe how its destination responds to various types of requests.
#
# We capture two kinds of information here. The first is the raw timings per
# request, and the second is the timings per byte of input.

require './statistical-aggregator'

class RequestProfiler
  constructor: ->
    @per_type_timings = {}      # ms
    @per_type_rates   = {}      # bytes/ms
    @error_rates      = {}      # errors per request
    @active           = {}      # active request distribution

    @currently_active = 0

  # Returns a function to be called on the error status and its reply body
  # size.
  start_timing: (type, body_size) ->
    time_aggregator  = @per_type_timings[type] ||= new StatisticalAggregator()
    rate_aggregator  = @per_type_rates[type]   ||= new StatisticalAggregator()
    error_aggregator = @error_rates[type]      ||= new StatisticalAggregator()
    active           = @active[type]           ||= new StatisticalAggregator()

    active.push(@currently_active++)

    start = Date.now()
    return (err, reply_size) =>
      @currently_active--
      elapsed_time = Date.now() - start                 # ms
      transfer_size = 1000 + body_size + reply_size     # bytes (+ 1kb of HTTP)
      transfer_rate = transfer_size / elapsed_time      # bytes/ms
      error_rate    = if err then 1 else 0              # errors/request

      time_aggregator.push elapsed_time
      rate_aggregator.push transfer_rate
      error_aggregator.push error_rate
