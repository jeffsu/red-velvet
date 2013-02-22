{fork} = require 'child_process'

WorkerShell   = require './worker-shell'
ForemanHealth = require '../meta/foreman-health'
www           = require '../transport/www'
config        = require '../config'
io            = require 'socket.io'
{EventEmitter} = require 'events'

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

    @www.get '/output', (req, res) =>
      res.render 'output'
 

#    @io = require('socket.io').listen(@www)
#
#    @io.sockets.on 'output', (socket) =>
#      socket.on 'listen', (data) =>
#        listener = (message) =>
#          socket.emit 'out', message
#
#        @on 'out', listener
#
#        remove = =>
#          @removeListener 'out', listener
#
#        socket.on 'disconnect', remove

    @www.listen @port
    console.log "listening at port #{@port}"

    @grid = config.grid
    @grid.on 'updated', =>
      # Match up workers with our workers. If we see a new one in the
      # "spinup" state, spin it up.
      our_ports = @grid.hosts[@host]
      cluster   = []
      for port, cell of our_ports
        unless @workers[port]
          if cell.status == 'spinup'
            @grid.write @host, port, 'status', 'inactive'
            cluster.push {host: @host, port: port, roles: cell.roles}
            @addWorker(cell.roles, port)

      @setCluster(cluster)

  run: ->
    console.log 'bootup sequence initiated'
    @checkController =>
      @register =>
        @grid.sync()
      
  spawnController: ->
    child = fork "#{__dirname}/controller-runner", { env: process.env, silent: true }

    child.stdout.on 'data', (chunk) ->
      console.log chunk.toString().trim()

    child.stderr.on 'data', (chunk) ->
      console.log chunk.toString().trim()
    
  checkController: (cb) ->
    config.checkController (err, host) =>
      console.log err if err
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
    worker.on 'out', (message) ->
      @emit 'out', { message: message, port: port }

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
