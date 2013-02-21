# Statistical aggregators collect quantitative samples and record properties
# about the resulting distributions.

class StatisticalAggregator
  constructor: ->
    @quantized_log_buckets = []
    @total                 = 0.0
    @n                     = 0

  push: (time) ->
    @total += time
    @n++

    quantized_log = Math.round Math.log(1 + Math.abs time)

    until @quantized_log_buckets.length >= quantized_log
      @quantized_log_buckets.push 0

    @quantized_log_buckets[quantized_log]++

  average: ->
    @total / @n || 0.0

  toString: ->
    "mean: #{@average()}; n: #{@n}; distribution: #{@quantized_log_buckets}"
