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
    @port     = config.port
    @workers  = []
    @www      = www()

    @www.get '/', (req, res) =>
      res.render 'foreman', foreman: this

    @www.post '/assign', (req, res) =>
      roles = req.body
      console.log 'assigning', roles
      @killWorkers()
      @addWorker roles

      # Workers are synchronous; once instantiated, we're good
      res.writeHead 200, {}
      res.end()

    @www.post '/set-cluster', (req, res) =>
      cluster = req.body
      console.log 'setting cluster', cluster
      @setCluster cluster

      res.writeHead 200, {}
      res.end()

    @www.listen @port
    console.log "forman is listening at port #{@port}"

  run: ->
    console.log 'bootup sequence initiated'
    @checkController =>
      @register =>
      
  spawnController: ->
    console.log 'spawning controller'
    fork "#{__dirname}/controller-runner"
    
  checkController: (cb) ->
    console.log 'checking controller'
    config.checkController (host) =>
      @spawnController() if host is config.host
      cb()

  register: (cb) ->
    config.set 'register', cb
    @persistHealth()
    cb() if cb

  persistHealth: ->
    saveHealth = =>
      hash = {}
      hash[w.port] = JSON.stringify w.getMetadata() for w in @workers
      config.saveHealth hash
    setInterval saveHealth, INTERVAL

  killWorkers: ->
    w.kill() for w in @workers
    @workers.length = 0
    
  # array of [ role, partition ]
  addWorker: (roles, port = @port + @workers.length + 2) ->
    worker = new WorkerShell(@host, port, @file)
    @workers.push worker
    for r in roles
      role  = r[0]
      partition = r[1] || 0
      worker.assume(role)
    worker

  # sets cluster configuration 
  # to all workers so they know 
  # where all the other workers are
  setCluster: (data) ->
    w.send({ type: 'cluster', data: data }) for w in @workers

module.exports = Foreman
