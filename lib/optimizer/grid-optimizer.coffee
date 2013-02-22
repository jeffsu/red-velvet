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

FREE_MEMORY_TARGET       = 0.2          # 20% of memory is free
EVENT_LOOP_PURITY_TARGET = 0.8          # dimensionless, 0 <= x <= 1
EVENT_LOOP_SHIFT         = 4            # powers of 2 (< 16ms is fine)
TRANSFER_TIME_LIMIT      = 0.8          # 80% of request time is network

class GridOptimizer
  constructor: ->

  # Produce a hash like this:
  # {"host:port": {network:   0.4,
  #                memory:    0.5,
  #                eventloop: 0.1},
  #  ...}
  #
  # Each bottleneck metric is in the range [0, 1], with 1 being the slowest.
  bottlenecks: (grid) ->
    result = {}
    for host, row of grid
      for port, cell of row
        result["#{host}:#{port}"] =
          network:   @network_loss_badness(grid, cell)
          memory:    @memory_badness(grid, cell)
          eventloop: @event_loop_badness(grid, cell)
    result

  # Specific bottleneck measurements
  memory_badness: (grid, host) ->
    foreman    = @foreman_for(grid, host)
    free_ratio = foreman.health.free_memory / foreman.hardware.total_memory
    return 0 if free_ratio > FREE_MEMORY_TARGET
    return 1.0 - (free_ratio / FREE_MEMORY_TARGET)

  network_loss_badness: (grid, server) ->
    server_total   = new StatisticalAggregator()
    server_profile = server.health.server_profile
    for role, stats of server_profile
      server_total = server_total.plus(StatisticalAggregator.fromJSON stats)

    # Now gather up client-side statistics.
    client_total = new StatisticalAggregator()
    clients      = @all_cells (cell, host, port) ->
      !(host == server.host && port == server.port)

    for c in clients
      if stats_for_server = c.client_profiles["#{server.host}:#{server.port}"]
        for role, stats of stats_for_server
          client_total = client_total.plus(StatisticalAggregator.fromJSON stats)

    server_time = server_total.total
    client_time = client_total.total
    return 1.0 - (server_time / Math.max(server_time, client_time))

  event_loop_badness: (grid, server) ->
    purity = 1.0 - StatisticalAggregator().fromJSON(server.event_latency)
                                          .shifted_by(EVENT_LOOP_SHIFT)
                                          .impurity()

    return 0.0 if purity >= EVENT_LOOP_PURITY_TARGET
    return 1.0 - (purity / EVENT_LOOP_PURITY_TARGET)

  # Cell retrieval functions
  all_cells: (grid, filter) ->
    result = []
    for host, row of grid
      for port, cell of row
        result.push cell if filter cell, host, port
    result

  foreman_for: (grid, host) ->
    machine_row = grid.hosts[host]
    for port, cell of machine_row
      return cell if cell.type == 'foreman'

  workers_for: (grid, host) ->
    machine_row = grid.hosts[host]
    (cell for port, cell of machine_row when cell.type == 'worker')

  all_foremen: (grid) ->
    (cell for cell in @all_cells(grid) when cell.type == 'foreman')

  all_workers: (grid) ->
    (cell for cell in @all_cells(grid) when cell.type == 'worker')

module.exports = GridOptimizer
