{fork} = require 'child_process'

WorkerShell = require './worker-shell'
www = require '../transport/www'
config = require '../config'

INTERVAL = 1000
class Foreman

  constructor: ->
    @file     = config.file
    @host     = config.host
    @port     = config.port
    @workers  = []
    @www      = www()

    @www.get '/', (req, res) =>
      res.render 'foreman', foreman: this

    @www.get '/allocate.json', (req, res) =>
      # Body of the request is structured like this:
      # [{port: X, role: Y}, ...]
      machines = JSON.parse req.body.data
      for {port, role} in machines
        @fork(role, port)

      # Workers are synchronous; once instantiated, we're good
      res.writeHead 200, {}
      res.end()

    @www.listen @port
    console.log "forman is listening at port #{@port}"


  run: ->
    console.log 'bootup sequence initiated'
    @checkController =>
      @register =>
        @start()
      
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

  start: ->
    layout = config.layout
    roleNames = layout.getRoleNames()
    schema = ([r, 1] for r in roleNames)
    @setSchema(schema)

    @persistHealth()

    i = 0
    cluster = ([ w.host, w.port, [ [roleNames[i++] ]] ] for w in @workers)
    @setCluster cluster

  persistHealth: ->
    saveHealth = =>
      hash = {}
      hash[w.port] = JSON.stringify w.getMetadata() for w in @workers
      config.saveHealth hash
    setInterval saveHealth, INTERVAL

  # array of [ role, count || 1 ]
  setSchema: (roles) ->
    @killWorkers()

    n = @workers.length
    i = 0
    for r in roles
      role  = r[0]
      count = r[1] || 1

      for j in [1..count]
        @fork(role)
  
  killWorkers: ->
    w.kill() for w in @workers
    @workers.length = 0
    
  fork: (role, port = @port + @workers.length + 2) ->
    worker = new WorkerShell(@host, port, @file)
    @workers.push worker
    worker.assume(role)
    worker

  # sets cluster configuration 
  # to all workers so they know 
  # where all the other workers are
  setCluster: (data) ->
    w.send({ type: 'cluster', data: data }) for w in @workers

module.exports = Foreman
