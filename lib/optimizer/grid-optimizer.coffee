# Grid optimization consists of identifying bottlenecks and applying various
# transformations to the grid to alleviate them. Optimization is an incremental
# process that is iterated continuously; it is not generally assumed to
# converge since the workload characteristics change over time.
#
# We look for the following situations:
# 1. A machine's network bandwidth is saturated.
# 2. A machine's disk is saturated.
# 3. A machine is swapping to disk (memory saturated).
# 4. A worker's event loop is saturated.
#
# These problems can be solved like this:
# 1. Move some roles to other machines, or replicate roles.
# 2. Ditto.
# 3. Remove workers from the problematic machine.
# 4. Create more same-role workers on the machine.
#
# We can detect the existence of these problems with these signals:
# 1. Discrepancies between client and server timings for large payloads.
# 2. Non-CPU, non-event-loop delays (we can assume disk, but really it could be
#    anything).
# 3. Low free memory and erratic process.nextTick timings.
# 4. Long process.nextTick reply times.
#
# It isn't quite as easy as just moving some arbitrary roles around. Ideally we
# determine the resource requirements of each role individually and optimize
# specifically to alleviate particular bottlenecks.

class GridOptimizer
  constructor: ->

  optimize: (grid, registration) ->
    grid

module.exports = GridOptimizer
