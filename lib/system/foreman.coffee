{fork} = require 'child_process'

WorkerShell   = require './worker-shell'
ForemanHealth = require '../meta/foreman-health'
www           = require '../transport/www'
config        = require '../config'

INTERVAL = 1000
class Foreman

  constructor: ->
    @file     = config.file
    @layout   = config.layout
    @host     = config.host
    @port     = +config.port    # numeric coercion necessary here
    @workers  = {}              # a hash from port -> [[role, partition], ...]
    @www      = www()

    @health_checker = new ForemanHealth(@)

    @www.get '/', (req, res) =>
      res.render 'foreman', foreman: this

    @www.get '/slides', (req, res) =>
      res.render 'slides'

    # Assign request: redo all of the nodes managed by this foreman. Causes a
    # brief service outage and kills active send queues.
    @www.post '/assign.json', (req, res) =>
      {roles, port} = JSON.parse req.body.data
      @killWorkers()
      @addWorker roles, port

      # Workers are synchronous; once instantiated, we're good
      res.writeHead 200, {}
      res.end()

    # Allocate worker request: like /assign, but does not stop any servers.
    # This allows the controller to communicate with existing workers
    # individually.
    @www.post '/allocate.json', (req, res) =>
      {roles, port} = JSON.parse req.body.data
      @addWorker roles, port

      res.writeHead 200, {}
      res.end()

    # Set-cluster request: updates each worker with a new topology description?
    @www.post '/set-cluster.json', (req, res) =>
      cluster = JSON.parse req.body.data
      @setCluster cluster

      res.writeHead 200, {}
      res.end()

    @www.listen @port
    config.foreman_log "listening at port #{@port}"

    @grid = config.grid
    @grid.on 'updated', =>
      # Match up workers with our workers. If we see a new one in the
      # "spinup" state, spin it up.
      our_ports = @grid.hosts[@host]
      for port, cell of our_ports
        unless @workers[port]
          if cell.status == 'spinup'
            @grid.write @host, port, 'status', 'inactive'
            @addWorker(cell.roles, port)

  run: ->
    config.foreman_log 'bootup sequence initiated'
    @checkController =>
      @register =>
        @grid.sync()
      
  spawnController: ->
    child = fork "#{__dirname}/controller-runner", { env: process.env, silent: true }

    child.stdout.on 'data', (chunk) ->
      config.controller_log chunk.toString().trim()

    child.stderr.on 'data', (chunk) ->
      config.controller_log chunk.toString().trim()
    
  checkController: (cb) ->
    config.checkController (err, host) =>
      config.foreman_log err if err
      @spawnController() if host is config.host
      cb(err)

  register: (cb) ->
    @grid = config.grid
    hash =
      type: 'foreman'
      status: 'active'
      layout: config.file
      hardware:
        cpus: config.cpus
        totalmem: config.totalmem
    @grid.writeHash @host, @port, hash, =>
      cb() if cb

  killWorkers: ->
    for port, w of @workers
      w.kill()
      delete @workers[port]

  # roles is array of [ role, partition ]
  addWorker: (roles, port) ->
    if @workers[port]
      throw new Error("foreman: cannot reassign running worker")

    @workers[port] = worker = new WorkerShell(@host, port, @file)
    for r in roles
      role      = r[0]
      partition = r[1] || 0
      worker.assume(role, partition)
    worker

  # sets cluster configuration 
  # to all workers so they know 
  # where all the other workers are
  setCluster: (data) ->
    w.send({ type: 'cluster', data: data }) for port, w of @workers

module.exports = Foreman
