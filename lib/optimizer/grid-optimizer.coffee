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
    for host, row of grid
      for port, cell of row
        cell_id = "#{host}:#{port}"
        if network_analyses[cell_id]
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
    server_total   = new StatisticalAggregator()
    server_profile = server.health.server_profile
    for role, stats of server_profile
      server_total = server_total.plus(StatisticalAggregator.fromJSON stats)

    # Now gather up client-side statistics.
    all_clients_total = new StatisticalAggregator()
    clients = grid.all_cells (cell, host, port) ->
      !(host == server.host && port == server.port)

    client_distribution = new StatisticalAggregator()
    role_distribution   = new StatisticalAggregator()
    client_totals       = {}
    role_totals         = {}

    for c in clients
      if c.client_profiles
        if stats_for_server = c.client_profiles["#{server.host}:#{server.port}"]
          client_id         = "#{c.host}:#{c.port}"
          this_client_total = new StatisticalAggregator()

          for role, stats of stats_for_server
            stats = StatisticalAggregator.fromJSON stats
            role_totals[role] ||= new StatisticalAggregator()
            role_totals[role] = role_totals[role].plus stats
            client_distribution.push stats.average()

            this_client_total = this_client_total.plus stats
            all_clients_total = all_clients_total.plus stats

          client_totals[client_id] = this_client_total

    role_averages = {}
    role_averages[r] = v.average() for r, v of role_totals

    client_averages = {}
    client_averages[c] = v.average() for c, v of client_totals

    server_time = server_total.average()
    client_time = all_clients_total.average()

    loss_ratio:      1.0 - (server_time / Math.max(server_time, client_time))
    role_impurity:   role_distribution.impurity()
    client_impurity: client_distribution.impurity()
    role_averages:   role_averages
    client_averages: client_averages

  # Specific bottleneck measurements
  memory_badness: (grid, host) ->
    foreman    = grid.foreman_for(host)
    free_ratio = foreman.health.free_memory / foreman.hardware.total_memory
    return 0 if free_ratio > FREE_MEMORY_TARGET
    return 1.0 - (free_ratio / FREE_MEMORY_TARGET)

  event_loop_badness: (grid, server) ->
    purity = 1.0 - StatisticalAggregator().fromJSON(server.event_latency).
                                           shifted_by(EVENT_LOOP_SHIFT).
                                           impurity()

    return 0.0 if purity >= EVENT_LOOP_PURITY_TARGET
    return 1.0 - (purity / EVENT_LOOP_PURITY_TARGET)

  network_loss_badness: (network_analysis) ->
    loss = network_analysis.loss_ratio
    return 0.0 if loss <= NETWORK_LOSS_TARGET
    return (loss - NETWORK_LOSS_TARGET) / (1.0 - NETWORK_LOSS_TARGET)

  # Cell retrieval functions

module.exports = GridOptimizer
