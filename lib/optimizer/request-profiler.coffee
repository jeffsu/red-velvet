# Request profilers collect statistics per request type. Each client (which
# itself is parameterized by the destination) owns a request profiler to
# describe how its destination responds to various types of requests.
#
# We capture two kinds of information here. The first is the raw timings per
# request, and the second is the timings per byte of input.

StatisticalAggregator = require './statistical-aggregator'

class RequestProfiler
  constructor: ->
    @per_type_timings = {}      # ms/request
    @per_type_rates   = {}      # (bytes/ms)/request
    @error_rates      = {}      # errors/request
    @active           = {}      # #active requests when we get a new one

    @currently_active = 0

  # Returns a function to be called on the error status and its reply body
  # size. For example:
  #
  #   profile = my_profiler.start_timing('foo', 50)
  #   ...
  #   profile(null, 10)         # no errors, reply had 10 bytes
  #
  # Doing this will automatically collect statistics about performance.

  start_timing: (type, body_size) ->
    time_aggregator  = @per_type_timings[type] ||= new StatisticalAggregator()
    rate_aggregator  = @per_type_rates[type]   ||= new StatisticalAggregator()
    error_aggregator = @error_rates[type]      ||= new StatisticalAggregator()
    active           = @active[type]           ||= new StatisticalAggregator()

    active.push(@currently_active++)

    start = Date.now()
    return (err, reply_size) =>
      @currently_active--
      elapsed_time = Date.now() - start                  # ms
      transfer_size = 1000 + body_size + reply_size      # bytes (+ 1kb of HTTP)
      transfer_rate = transfer_size / (1 + elapsed_time) # bytes/ms
      error_rate    = if err then 1 else 0               # errors/request

      time_aggregator.push elapsed_time
      rate_aggregator.push transfer_rate
      error_aggregator.push error_rate

  toJSON: ->
    per_type_timings: @per_type_timings.toJSON
    per_type_rates:   @per_type_rates.toJSON
    error_rates:      @error_rates.toJSON
    active_requests:  @active.toJSON

  fromJSON: (json) ->
    result = new RequestProfiler()
    @per_type_timings = StatisticalAggregator.fromJSON json.per_type_timings
    @per_type_rates   = StatisticalAggregator.fromJSON json.per_type_rates
    @error_rates      = StatisticalAggregator.fromJSON json.error_rates
    @active           = StatisticalAggregator.fromJSON json.active_requests
    result

module.exports = RequestProfiler
