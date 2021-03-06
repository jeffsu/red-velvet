{App}      = require '../app'

transport = require '../transport'

config       = require '../config'
{Server}     = transport
{Balancer}   = transport
{ClientPool} = transport

{WorkerHealth} = require '../meta'

# what kicks off running in the worker
class Worker
  constructor: (@transporter) ->
    @env    = process.env
    @host   = @env.RV_HOST
    @port   = @env.RV_PORT
    @setup()

  assume: (roleName, part=0) ->
    if role = @layout.getRole roleName
      console.log "worker #{@host}:#{@port} is assuming role #{roleName}[#{part}]"
      @app.assume role, part
      config.grid.write @host, @port, 'status', 'active'
    else
      config.grid.write @host, @port, 'status', 'error: role not found'

  # connect the dots
  setup: ->
    @layout = config.layout
    @app    = new App()

    # handle receiving requests
    @server = new transport.Server()

    @server.on 'emit', (packet) =>
      @app.handleEmit packet

    @server.on 'ask', (packet) =>
      @app.handleAsk packet

    @server.on 'migrate', (packet) =>
      @app.migrate packet

    # handle making requests
    @clientPool   = new ClientPool()
    @workerHealth = new WorkerHealth(@, @clientPool, @server)

    emitLookup = {}

    @app.on 'emit', (event, data, cb) =>
      roles = emitLookup[event] ||= @layout.getRolesFromEvent(event)
      @clientPool.emit(event, data, roles, cb)

    askLookup = {}
    @app.on 'ask', (q, data, cb) =>
      role = askLookup[q] ||= @layout.getRoleFromQuestion(q)
      @clientPool.ask(q, data, role, cb)

    @server.run @port, @app

    process.on 'message', (m) =>
      if m.type == 'assume'
        @assume(m.role, m.partition)

      if m.type == 'cluster'
        @clientPool.setCluster(m.data)

module.exports = Worker
