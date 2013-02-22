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
  return addresses.filter((a) -> a != '127.0.0.1')[0]

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
  
class Config
  constructor: ->
    @host     = host
    @cpus     = os.cpus().length
    @totalmem = os.totalmem()

  set: (args) ->
    for k, v in args
      this[k] = v

  getClient: (cb) ->
    if @clientReady
      return cb(null, @client)

    u = url.parse @redis
    @client = redis.createClient(u.port, u.hostname)
    @client.on 'ready', =>
      @clientReady = true
      cb(null, @client)

  get: (type, cb) ->
    @getClient (err, client) =>
      client.get KEYS.type, (err, result) ->
        if result
          cb(null, JSON.parse result)
        else
          cb(null, null)

  checkController: (cb) ->
    @getClient (err, client) =>
      client.eval controllerCode, 1, host, (err, result) ->
        # TODO handle error
        cb result

  set: (type, cb) ->
    data = {}
    data[key] = this[key] for key in ['host', 'port', 'file', 'cpus', 'totalmem']

    @getClient (err, client) =>
      str = JSON.stringify data
      client.set KEYS.type, str, (err) ->
        cb(err) if cb

module.exports = new Config()
