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
    @www.get '/', (req, res) =>
      console.log @grid.hosts
      res.render 'controller',
        controller: this
        config: config
        hosts: @grid.hosts
        bottlenecks: @bottlenecks
        network_analyses: @network_analyses

    @www.get '/workers/:host/:port', (req, res) =>
      port = req.params.port
      host = req.params.host
      res.render('worker-edit', worker: @grid.hosts[host][port])

    @www.post '/workers/:host/:port', (req, res) =>
      # TODO
      res.end()

    @www.listen(config.port + 1)

    @profiler            = new RequestProfiler()
    @optimizer           = new GridOptimizer()
    @initialized_workers = false

    @grid = config.grid

    update = => @update()
    setInterval(update, INTERVAL)
    @update()

  # This is the entry point for grid manipulation.
  manage: (grid) ->
    foremen = grid.all_foremen()
    return console.log 'waiting for foremen' unless foremen.length

    unless @initialized_workers
      @initialized_workers = true
      reserved = {}
      machine = 0
      for name, role of config.layout.roles
        for i in [0...role.partitions]
          (->
            f    = foremen[machine++ % foremen.length]
            host = f.host
            port = grid.port_for(host)

            # Hack for initialization
            port++ while reserved["#{host}:#{port}"]
            reserved["#{host}:#{port}"] = true

            console.log "allocating #{name}:#{i} on #{host}:#{port}"
            grid.allocate host, port, [[name, i]], ->
              grid.activate host, port
          )()

    @network_analyses = @optimizer.network_analyses(grid)
    @bottlenecks      = @optimizer.bottlenecks(grid, @network_analyses)

  update: ->
    # Synchronize the grid if we're not already doing so.
    return if @awaiting_grid
    @awaiting_grid = Date.now()

    profile = @profiler.start_timing 'grid-sync', 0
    @grid.sync (err) =>
      profile err, 0
      config.print_if err
      @awaiting_grid = false
      @manage @grid

module.exports = Controller
