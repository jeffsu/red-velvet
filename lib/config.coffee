argv  = require('optimist').argv
env   = process.env
cwd   = process.cwd()
os    = require 'os'
redis = require 'redis'
url   = require 'url'

getHost = ->
  ifaces = os.networkInterfaces()
  addresses = []
  for dev, iface of ifaces
    for details in iface
      if details.family == 'IPv4'
        addresses.push details.address
  return addresses.filter((a) -> a != '127.0.0.1' && a != 'localhost')[0]

host = getHost()

controllerCode = """
  local host = redis.call("get", "RV:CONTROLLER")
  if host then
    return host
  else
    redis.call("set", "RV:CONTROLLER", KEYS[1])
    return KEYS[1]
  end
  """

KEYS =
  cluster:  'RV:CLUSTER'
  register: "RV:REGISTER:#{host}"
  health:   "RV:HEALTH:#{host}"

PREFIXES =
  cluster:  'RV:CLUSTER'
  register: 'RV:REGISTER'
  health:   'RV:HEALTH'
  
class Config
  constructor: ->
    env = process.env
    @host     = host
    @file     = env.RV_FILE
    @port     = +env.RV_PORT
    @redis    = env.RV_REDIS || 'redis://127.0.0.1:6379'
    @env      = env.RV_ENV || 'local'
    @cpus     = os.cpus().length
    @totalmem = os.totalmem()

    @isForeman    = env.RV_TYPE == 'foreman'
    @isWorker     = env.RV_TYPE == 'worker'
    @isController = env.RV_TYPE == 'controller'

  start: ->
    return if @layout
    Grid    = require './meta/grid'
    @grid   = new Grid()
    @layout = require @file

  set: (args) ->
    for k, v in args
      this[k] = v

  getNewClient: (cb) ->
    u = url.parse @redis
    client = redis.createClient(u.port, u.hostname)
    client.on 'ready', =>
      @config_log 'redis ready'
      cb(null, client)

  getClient: (cb) ->
    if @clientReady
      return cb(null, @client)

    u = url.parse @redis
    @client = redis.createClient(u.port, u.hostname)
    @client.on 'ready', =>
      @config_log 'redis ready'
      @clientReady = true
      cb(null, @client)

  get: (type, cb) ->
    @getClient (err, client) =>
      @print_if err
      client.get KEYS[type], (err, result) =>
        @print_if err
        if result
          cb(null, JSON.parse result)
        else
          cb(err, null)

  checkController: (cb) ->
    @getClient (err, client) =>
      client.eval controllerCode, 1, host, (err, result) ->
        # TODO handle error
        cb err, result

  set: (type, cb) ->
    data = {}
    data[key] = this[key] for key in ['host', 'port', 'file', 'cpus', 'totalmem']

    @getClient (err, client) =>
      str = JSON.stringify data
      client.set KEYS[type], str, (err) ->
        cb(err) if cb

  log_multi: (prefix, args) ->
    sliced   = Array.prototype.slice.call(args)
    new_args = [`"\033[1;31mrv\033[0;0m"`, prefix].concat(sliced)
    console.log.apply(console, new_args)

  foreman_log:    -> @log_multi `"\033[1;32mforeman:\033[0;0m"`, arguments
  worker_log:     -> @log_multi `"\033[1;33mworker: \033[0;0m"`, arguments
  controller_log: -> @log_multi `"\033[1;34mcontrol:\033[0;0m"`, arguments
  debug_log:      -> @log_multi `"\033[1;35mdebug:  \033[0;0m"`, arguments
  config_log:     -> @log_multi `"\033[1;36mconfig: \033[0;0m"`, arguments
  error_log:      -> @log_multi `"\033[1;31merror:  \033[0;0m"`, arguments

  print_if: (err) -> @error_log err if err

  # health: {port: {...}}}
  saveHealth: (hash) ->
    grid.write host, port, 'health', json for port, json of hash

module.exports = new Config()
