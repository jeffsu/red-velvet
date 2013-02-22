{fork} = require 'child_process'

WorkerShell = require './worker-shell'
www    = require '../transport/www'
config = require '../config'

INTERVAL = 1000
class Foreman

  constructor: ->
    @file     = config.file
    @layout   = config.getLayout()
    @host     = config.host
    @port     = +config.port    # numeric coercion necessary here
    @workers  = {}              # a hash from port -> [[role, partition], ...]
    @www      = www()

    @www.get '/', (req, res) =>
      res.render 'foreman', foreman: this

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

  run: ->
    config.foreman_log 'bootup sequence initiated'
    @checkController =>
      @register =>
      
  spawnController: ->
    config.foreman_log 'spawning controller'
    fork "#{__dirname}/controller-runner"
    
  checkController: (cb) ->
    config.checkController (err, host) =>
      config.foreman_log err if err
      @spawnController() if host is config.host
      cb(err)

  register: (cb) ->
    config.set 'register', cb
    @persistHealth()
    cb() if cb

  persistHealth: ->
    saveHealth = =>
      hash = {}
      hash[port] = JSON.stringify w.getMetadata() for port, w of @workers
      config.saveHealth hash
    setInterval saveHealth, INTERVAL

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
      worker.assume(role)
    worker

  # sets cluster configuration 
  # to all workers so they know 
  # where all the other workers are
  setCluster: (data) ->
    w.send({ type: 'cluster', data: data }) for port, w of @workers

module.exports = Foreman
