{App}      = require '../app'

transport = require '../transport'

{Server}     = transport
{Balancer}   = transport
{ClientPool} = transport

# what kicks off running in the worker
class Worker
  constructor: (@transporter) ->
    @env    = process.env
    @host   = @env.RV_HOST
    @port   = @env.RV_PORT
    @setup()

  assume: (roleName) ->
    console.log('assuming:', roleName)
    if role = @layout.getRole roleName
      @app.assume role

  # connect the dots
  setup: ->
    @layout = require @env.RV_FILE
    @app    = new App()


    # handle receiving requests
    @server = new transport.Server()

    @server.on 'emit', (packet) =>
      @app.handleEmit packet

    @server.on 'ask', (packet) =>
      @app.handleAsk packet

    @server.on 'migrate', (params) =>
      @app.migrate params


    # handle making requests
    @clientPool   = new ClientPool()
    @workerHealth = new WorkerHealth(@clientPool, @server)

    @app.on 'emit', (emit, data, cb) =>
      roles = @layout.getRoleNamesFromEmit(emit)
      @clientPool.emit(emit, data, roles, cb)

    @app.on 'ask', (question, data, cb) =>
      role = @layout.getRoleNameFromAsk(question)
      @clientPool.ask(question, data, role, cb)

    @server.run @port

    process.on 'message', (m) =>
      if m.type == 'assume'
        @assume(m.role)

      if m.type == 'cluster'
        @clientPool.setCluster(m.data)

module.exports = Worker
