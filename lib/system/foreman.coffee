{fork} = require 'child_process'

WorkerShell = require './worker-shell'
www = require '../transport/www'
config = require '../config'

class Foreman

  constructor: (@host, @file) ->
    @port     = config.port
    @workers  = []
    @www      = www()

    @www.get '/', (req, res) =>
      res.render 'foreman', foreman: this

    @www.listen @port
    console.log "forman is listening at port #{@port}"

  runSteps: ->
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
    
  fork: (role) ->
    port = @port + @workers.length + 2
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
