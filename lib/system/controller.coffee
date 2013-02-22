www             = require '../transport/www'
config          = require '../config'
RequestProfiler = require '../optimizer/request-profiler'
GridOptimizer   = require '../optimizer/grid-optimizer'

INTERVAL = 2000

class Controller
  constructor: ->
    @www = www()
    @www.get '/', (req, res) ->
      res.render('controller', controller: config)

    @www.listen(config.port + 1)

    @profiler              = new RequestProfiler()
    @optimizer             = new GridOptimizer()
    @awaiting_grid         = false
    @awaiting_registration = false

    update = => @update()
    setInterval(update, INTERVAL)
    @update()

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
      register_profile(null, 0)
      @awaiting_registration = false
      @registration          = registration
      @optimize @grid, @registration unless @awaiting_grid

    register_grid = @profiler.start_timing('grid', 0)
    config.get 'grid', (err, grid) =>
      register_grid(null, 0)
      @awaiting_grid = false
      @grid          = grid
      @optimize @grid, @registration unless @awaiting_registration

module.exports = Controller
