www             = require '../transport/www'
config          = require '../config'
RequestProfiler = require '../optimizer/request-profiler'
GridOptimizer   = require '../optimizer/grid-optimizer'
request         = require 'request'

INTERVAL = 2000

class Controller
  constructor: ->
    console.log 'starting controller'
    @www = www()
    @www.get '/', (req, res) ->
      res.render('controller', controller: this, config: config)

    @www.listen(+config.port + 1)

    @profiler               = new RequestProfiler()
    @optimizer              = new GridOptimizer()
    @awaiting_grid          = false
    @awaiting_registration  = false
    @previous_machine_count = 0

    @registration = []
    @grid         = {}

    update = => @update()
    setInterval(update, INTERVAL)
    @update()


  localHack: ->
    console.log 'starting localHack'
    base_url = "http://#{config.host}:#{config.port}"
    
    # assume 2 workers 1 foreman
    layout = config.getLayout()
    workers = [ [], [] ]
    roles = []

    n = 0
    for name, role of layout.roles
      for i in [ 0...role.partitions ]
        workers[n%2].push([ name, i ])
        roles.push role.name, i
        n++

    # assign
    for w, i in workers
      console.log 'sending assign', JSON.stringify({roles: w, port: 8002 + i})
      request
        uri: "#{base_url}/assign.json"
        method: 'POST'
        form:
          data: JSON.stringify {roles: w, port: 8002 + i}

    # set cluster
    i = 0
    cluster = ([ w.host, w.port, roles[i] ] for w, i in workers)
    console.log 'sending cluster', cluster
    request
      uri: "#{base_url}/set-cluster.json"
      method: 'POST'
      form:
        data: JSON.stringify cluster

  # This is the entry point for grid manipulation.
  manage: (grid, registration) ->
    if @previous_machine_count > 0
      # We've already got machines provisioned. Just make sure we've still got
      # them; otherwise start over when we get new ones.
      unless @previous_machine_count = registration.length      # assign [sic]
        return console.log 'controller: not rearranging empty grid!'

      @optimize grid, registration
    else
      # A new grid, so we need to initialize it with some roles. We can do this
      # only when we have registrations.
      unless registration.length
        return console.log 'controller: awaiting registrations'

      # Ok, now we have some nodes. Disperse roles evenly in the absence of
      # more specific information. An invariant is that there exists at least
      # one worker to handle each role.
      console.log 'controller: got registrations ', registration
      machines = []
      for machine in registration
        machines.push machine

      console.log 'TODO'

      @previous_machine_count = registration.length

  # Optimization happens when we have an already-configured grid and need to
  # rearrange it. If we've just booted up, optimize is not called.
  optimize: (grid, registration) ->
    # Get the new grid from the optimizer...
    new_grid = @optimizer.optimize(grid, registration)

    # ... and apply the diffs to the foreman nodes.
    console.log "applying #{new_grid} (TODO)"

  update: ->
    if @awaiting_grid || @awaiting_registration
      console.log 'not updating; already going'
      return

    @awaiting_grid         = true
    @awaiting_registration = true

    console.log @profiler.toJSON()

    register_profile = @profiler.start_timing('register', 0)
    config.get 'register', (err, registration) =>
      console.log 'controller: failed to get registration', err if err
      register_profile(null, 0)
      @awaiting_registration = false
      @registration          = registration
      @manage @grid, @registration unless @awaiting_grid

    register_grid = @profiler.start_timing('grid', 0)
    config.get 'grid', (err, grid) =>
      console.log 'controller: failed to get grid', err if err
      register_grid(null, 0)
      @awaiting_grid = false
      @grid          = grid
      @manage @grid, @registration unless @awaiting_registration

module.exports = Controller
