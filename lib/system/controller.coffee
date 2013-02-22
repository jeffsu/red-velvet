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

    @www.listen(config.port + 1)

    @profiler               = new RequestProfiler()
    @optimizer              = new GridOptimizer()
    @previous_machine_count = 0

    @registration = []
    @grid         = config.grid

    update = => @update()
    setInterval(update, INTERVAL)
    @update()

  # This is the entry point for grid manipulation.
  manage: (grid, registration) ->

  update: ->
    # Synchronize the grid if we're not already doing so.
    return if @awaiting_grid
    @awaiting_grid = Date.now()

    profile = @profiler.start_timing 'grid-sync', 0
    @grid.sync (err) =>
      profile err, 0
      config.print_if err
      @awaiting_grid = false
      @manage grid

module.exports = Controller
