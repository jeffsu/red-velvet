# Statistical aggregators collect quantitative samples and record properties
# about the resulting distributions.

class StatisticalAggregator
  constructor: ->
    @quantized_log_buckets ||= []
    @total                 ||= 0.0
    @n                     ||= 0

  push: (time) ->
    time ||= 0
    @total += time
    @n++
    quantized_log = Math.round Math.log(1 + Math.abs time)
    until @quantized_log_buckets.length > quantized_log
      @quantized_log_buckets.push 0
    @quantized_log_buckets[quantized_log]++
    @

  average:               -> @total / @n || 0.0
  impurity:              -> @sum(x * x for x in @normalized())
  normalized: (base = 0) -> ((x + base) / total for x in @quantized_log_buckets)

  plus: (that) ->
    result       = new StatisticalAggregator()
    result.total = @total + that.total
    result.n     = @n     + that.n

    result.quantized_log_buckets =
      ((@quantized_log_buckets[i]     || 0) +
       (that.quantized_log_buckets[i] || 0) for i in [0..Math.max(
         @quantized_log_buckets.length, that.quantized_log_buckets.length)])
    result

  sum: (xs) ->
    total = 0
    total += x for x in xs
    total

  toString: ->
    "mean: #{@average()}; n: #{@n}; distribution: #{@quantized_log_buckets}"

  toJSON: ->
    {total: @total, n: @n, distribution: @quantized_log_buckets}

  @fromJSON: ({total, n, distribution}) ->
    result = new StatisticalAggregator()
    result.total                 = total
    result.n                     = n
    result.quantized_log_buckets = distribution
    result

module.exports = StatisticalAggregator
