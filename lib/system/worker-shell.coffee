{EventEmitter} = require 'events'
{fork} = require 'child_process'

# proxy class for worker process
class WorkerShell extends EventEmitter
  constructor: (@host, @port, @file) ->
    @env = {}
    @env[k] = v for v, k in process.env
    @env.RV_HOST = @host
    @env.RV_PORT = @port
    @env.RV_FILE = @file
    @child = null
    @roles = {}
    @fork()

  getMetadata: =>
    @metadata

  assume: (role) ->
    if !@roles[role]
      @child.send({ type: 'assume', role: role })
      @roles[role] = true

  send: (data) ->
    @child.send(data) if @child

  fork: ->
    @child = fork __dirname + "/worker-runner.js", { env: @env }
    for r in @roles
      @assume r

    @child.on 'exit', =>
      restart = =>
        @fork()
      setTimeout restart, 2000

    @child.on 'message', (msg) =>
      @metadata = msg.data if msg.type == 'health'


  kill: (sig='SIGINT') ->
    @child.kill sig

module.exports = WorkerShell
