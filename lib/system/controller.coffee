www             = require '../transport/www'
config          = require '../config'
RequestProfiler = require '../optimizer/request-profiler'
GridOptimizer   = require '../optimizer/grid-optimizer'
request         = require 'request'

INTERVAL = 2000

class Controller
  constructor: ->
    config.controller_log 'starting controller'
    @www = www()
    @www.get '/', (req, res) =>
      res.render('controller', controller: this, config: config)

    @www.listen(+config.port + 1)

    @profiler               = new RequestProfiler()
    @optimizer              = new GridOptimizer()
    @previous_machine_count = 0

    @registration = []
    @grid         = {}

    update = => @update()
    setInterval(update, INTERVAL)
    @update()

  # This is the entry point for grid manipulation.
  manage: (grid, registration) ->
    if @previous_machine_count > 0
      # We've already got machines provisioned. Just make sure we've still got
      # them; otherwise start over when we get new ones.
      unless @previous_machine_count = registration.length      # assign [sic]
        return config.controller_log 'not rearranging empty grid!'

      config.controller_log 'optimizing the grid (TODO)'
      @optimize grid, registration
    else
      # A new grid, so we need to initialize it with some roles. We can do this
      # only when we have registrations.
      unless registration.length
        return config.controller_log 'awaiting registrations'

      # Ok, now we have some nodes. Disperse roles evenly in the absence of
      # more specific information. An invariant is that there exists at least
      # one worker to handle each role (though a worker can handle more than
      # one role at a time).
      machine_index = 0
      layout        = config.getLayout()
      machines      = ([] for r in registration)

      # Initially start up a new worker for each role on the machine. Later on
      # we can consolidate if we observe low free memory.
      cluster = []
      for name, role of layout.roles
        for i in [0...role.partitions]
          index  = machine_index++ % machines.length
          reg    = registration[index]
          worker =
            host:  reg.host
            port:  reg.port + machines[index].length + 2
            roles: [[name, i]]

          machines[index].push worker
          cluster.push worker

      # Set up the systems.
      for r, i in registration
        m = machines[i]
        for w in m
          request
            uri:    "http://#{r.host}:#{r.port}/assign.json"
            method: 'POST'
            form:
              data: JSON.stringify {roles: w.roles, port: w.port}

      # Commit the cluster.
      for r in registration
        request
          uri:    "http://#{r.host}:#{r.port}/set-cluster.json"
          method: 'POST'
          form:
            data: JSON.stringify cluster

      @previous_machine_count = registration.length

  # Optimization happens when we have an already-configured grid and need to
  # rearrange it. If we've just booted up, optimize is not called.
  optimize: (grid, registration) ->
    # Get the new grid from the optimizer...
    new_grid = @optimizer.optimize(grid, registration)

    # ... and apply the diffs to the foreman nodes.
    config.controller_log "applying changes (TODO)"

  update: ->
    # Synchronize the grid if we're not already doing so.
    return if @awaiting_grid
    @awaiting_grid = Date.now()

    profile = @profiler.start_timing 'grid-sync', 0
    @grid.sync (err) =>
      config.print_if err
      profile err, 0
      @awaiting_grid = false
      @manage grid

module.exports = Controller
