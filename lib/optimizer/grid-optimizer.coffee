# Grid optimization consists of identifying bottlenecks and applying various
# transformations to the grid to alleviate them. Optimization is an incremental
# process that is iterated continuously; it is not generally assumed to
# converge since the workload characteristics change over time.
#
# We look for the following situations:
# 1. A machine's network bandwidth is saturated.
# 2. A machine is swapping to disk (memory saturated).
# 3. A worker's event loop is saturated.
#
# These problems can be solved like this:
# 1. Move some roles to other machines, or replicate roles.
# 2. Remove workers from the problematic machine.
# 3. Create more same-role workers on the machine.
#
# We can detect the existence of these problems with these signals:
# 1. Discrepancies between client and server timings for large payloads.
# 2. Low free memory and erratic process.nextTick timings.
# 3. Long process.nextTick reply times.
#
# It isn't quite as easy as just moving some arbitrary roles around. Ideally we
# determine the resource requirements of each role individually and optimize
# specifically to alleviate particular bottlenecks. We also consider the
# migration cost of each one if the nodes provide this information. (TODO)

StatisticalAggregator = require './statistical-aggregator'

FREE_MEMORY_TARGET       = 0.2          # >= 20% of memory is free
EVENT_LOOP_PURITY_TARGET = 0.8          # dimensionless, 0 <= x <= 1
EVENT_LOOP_SHIFT         = 4            # powers of 2 (< 16ms is fine)
NETWORK_LOSS_TARGET      = 0.7          # <= 70% of request time is network

class GridOptimizer
  constructor: ->

  # Produce a hash like this:
  # {"host:port": {network:   0.4,
  #                memory:    0.5,
  #                eventloop: 0.1},
  #  ...}
  #
  # Each bottleneck metric is in the range [0, 1], with 1 being the slowest.
  bottlenecks: (grid, network_analyses = @network_analyses(grid)) ->
    result = {}
    for host, row of grid.hosts
      for port, cell of row
        cell_id = "#{host}:#{port}"
        if cell.health && network_analyses[cell_id]
          result[cell_id] =
            network:   @network_loss_badness(network_analyses[cell_id])
            memory:    @memory_badness(grid, cell)
            eventloop: @event_loop_badness(grid, cell)
    result

  # General analyses used to make routing decisions
  network_analyses: (grid) ->
    result = {}
    for c in grid.all_cells((cell) -> !!cell.health)
      result["#{c.host}:#{c.port}"] = @network_analysis(grid, c)
    result

  network_analysis: (grid, server) ->
    return {} unless server.health?.server_profile

    server_total   = new StatisticalAggregator()
    server_profile = server.health.server_profile.per_type_timings
    for role, stats of server_profile
      server_total = server_total.plus(StatisticalAggregator.fromJSON stats)

    # Now gather up client-side statistics.
    all_clients_total = new StatisticalAggregator()
    clients = grid.all_cells (cell, host, port) ->
      !(host == server.host && port == server.port)

    client_totals = {}
    role_totals   = {}

    for c in clients
      client_id = "#{c.host}:#{c.port}"

      if cp = c.health?.client_profiles
        if stats_hash = cp["#{server.host}:#{server.port}"]
          for type, roles_hash of stats_hash
            hr = role_totals[type]   ||= {}
            hc = client_totals[type] ||= {}

            for role, stats of roles_hash
              stats = StatisticalAggregator.fromJSON stats
              hr[role] ||= new StatisticalAggregator()
              hr[role] = hr[role].plus stats

              if type == 'per_type_timings'
                all_clients_total = all_clients_total.plus stats

              hc[client_id] ||= new StatisticalAggregator()
              hc[client_id] = hc[client_id].plus stats

    role_average_times = {}
    role_average_times[r] = v.average() for r, v of role_totals.per_type_timings

    role_average_rates = {}
    role_average_rates[r] = v.average() for r, v of role_totals.per_type_rates

    client_average_times = {}
    client_average_times[c] = v.average() for c, v of client_totals.per_type_timings

    client_average_rates = {}
    client_average_rates[r] = v.average() for r, v of client_totals.per_type_rates

    server_time = server_total.average()
    client_time = all_clients_total.average()

    loss_ratio:           1.0 - (server_time / Math.max(server_time, client_time))
    server_total_time:    server_time
    client_total_time:    client_time
    server_total_n:       server_total.n
    client_total_n:       all_clients_total.n
    role_average_times:   role_average_times
    role_average_rates:   role_average_rates
    client_average_times: client_average_times
    client_average_rates: client_average_rates

  # Specific bottleneck measurements
  memory_badness: (grid, host) ->
    return 0 unless foreman = grid.foreman_for(host)
    free_ratio = foreman.health.free_memory / foreman.hardware.total_memory
    return 0 if free_ratio > FREE_MEMORY_TARGET
    return 1.0 - (free_ratio / FREE_MEMORY_TARGET)

  event_loop_badness: (grid, server) ->
    return 0.0 unless server.health?.event_latency
    purity = 1.0 - StatisticalAggregator.fromJSON(server.health.event_latency).
                                         shifted_by(EVENT_LOOP_SHIFT).
                                         impurity()

    return 0.0 if purity >= EVENT_LOOP_PURITY_TARGET
    return 1.0 - (purity / EVENT_LOOP_PURITY_TARGET)

  network_loss_badness: (network_analysis) ->
    return 0 unless network_analysis.loss_ratio
    loss = network_analysis.loss_ratio
    return 0.0 if loss <= NETWORK_LOSS_TARGET
    return (loss - NETWORK_LOSS_TARGET) / (1.0 - NETWORK_LOSS_TARGET)

module.exports = GridOptimizer
