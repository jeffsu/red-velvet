{EventEmitter} = require 'events'
{fork} = require 'child_process'

# proxy class for worker process
class WorkerShell extends EventEmitter
  constructor: (@host, @port, @file) ->
    @env = {}
    @env[k] = v for v, k in process.env
    @env.RV_HOST   = @host
    @env.RV_PORT   = @port
    @env.RV_FILE   = @file
    @env.RV_TYPE   = 'worker'
    @child = null
    @roles = {}
    @fork()

  getMetadata: =>
    @metadata || null

  assume: (role, part) ->
    if !@roles[role]
      @child.send({ type: 'assume', role: role, partition: part })
      @roles[role] = true

  send: (data) ->
    @child.send(data) if @child

  fork: ->
    @child = fork __dirname + "/worker-runner.js", { env: @env, silent: true }

    @child.stderr.on 'data', (chunk) ->
      config.worker_log chunk.toString().trim()

    @child.stdout.on 'data', (chunk) ->
      config.worker_log chunk.toString().trim()

    for r in @roles
      @assume r

    @child.on 'exit', =>
      restart = =>
        @fork()
      setTimeout restart, 2000

    @child.on 'message', (msg) =>
      if msg.type == 'health'
        @emit('health', msg.data)
        @metadata = msg.data


  kill: (sig='SIGINT') ->
    @child.kill sig

module.exports = WorkerShell
