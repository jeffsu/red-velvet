# Grid optimization consists of identifying bottlenecks and applying various
# transformations to the grid to alleviate them. Optimization is an incremental
# process that is iterated continuously; it is not generally assumed to
# converge since the workload characteristics change over time.
#
# We look for the following situations:
# 1. A machine's network bandwidth is saturated.
# 2. A machine's disk is saturated.
# 3. A machine is swapping to disk (memory saturated).
# 4. A machine's CPU is saturated.
# 5. A worker's event loop is saturated.
#
# These problems can be solved like this:
# 1. Move some roles to other machines, or replicate roles.
# 2. Ditto.
# 3. Remove workers from the problematic machine.
# 4. Remove workers from the problematic machine.
# 5. Create more same-role workers on the machine.

class GridOptimizer
  constructor: ->

  optimize: (grid, registration) ->
    grid

module.exports = GridOptimizer
