# Statistical aggregators collect quantitative samples and record properties
# about the resulting distributions.

LOG_2 = Math.log 2

class StatisticalAggregator
  constructor: (@n = 0, @total = 0.0, @quantized_log_buckets = []) ->

  push: (time = 0) ->
    @total += time
    @n++
    quantized_log = Math.round(Math.log(1 + Math.abs time) / LOG_2) || 0
    quantized_log = Math.min(quantized_log, 1000)
    until @quantized_log_buckets.length > quantized_log
      @quantized_log_buckets.push 0
    @quantized_log_buckets[quantized_log]++
    @

  average:               -> @total / @n || 0.0
  impurity:              -> @sum(x * x for x in @normalized())
  normalized: (base = 0) -> ((x + base) / total for x in @quantized_log_buckets)

  shifted_by: (powers) ->
    new StatisticalAggregator(@n, @total, @quantized_log_buckets.slice(powers))

  plus: (that) ->
    new StatisticalAggregator(
      @n     + that.n,
      @total + that.total,
      ((@quantized_log_buckets[i]     || 0) +
       (that.quantized_log_buckets[i] || 0) for i in [0..Math.max(
         @quantized_log_buckets.length, that.quantized_log_buckets.length)]))

  sum: (xs) ->
    total = 0
    total += x for x in xs
    total

  toString: ->
    "mean: #{@average()}; n: #{@n}; distribution: #{@quantized_log_buckets}"

  toJSON: ->
    {total: @total, n: @n, distribution: @quantized_log_buckets}

  @fromJSON: ({total, n, distribution}) ->
    new StatisticalAggregator(n, total, distribution)

module.exports = StatisticalAggregator
