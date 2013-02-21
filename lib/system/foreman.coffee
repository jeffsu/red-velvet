WorkerShell = require './worker-shell'
www = require '../transport/www'
class Foreman

  constructor: (@host, @file) ->
    @port     = 9000
    @workers  = []
    @www      = www()

    @www.get '/', (req, res) =>
      res.render 'foreman', { foreman: this }

    @www.listen @port

  runSteps: ->

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
    port = @port + @workers.length + 1
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
