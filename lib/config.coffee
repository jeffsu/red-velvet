argv  = require('optimist').argv
env   = process.env
cwd   = process.cwd()
redis = require 'redis'

getHost = ->
  os     = require('os')
  ifaces = os.networkInterfaces()
  addresses = []
  for dev, iface of ifaces
    for details in iface
      if details.family == 'IPv4'
        addresses.push details.address
  return addresses.filter((a) -> a != '127.0.0.1')[0]

host = getHost()

KEYS =
  cluster: 'RV:CLUSTER'
  health:  "RV:HEALTH:#{host}"
  
class Config
  constructor: ->
    @host     = host
    @port     = env.RV_HOST
    @file     = cwd + '/' + argv.file
    @env      = 'local'
    @redisUri = argv.redis || 'redis://localhost:6379'

  getClient: (cb) ->
    if @clientReady
      return cb(null, @client)

    @client = redis.createClient(@redisUri)
    @client.on 'ready', ->
      @clientReady = true
      cb(null, @client)

  get: (type, cb) ->
    @getClient (err, client) =>
      client.get KEYS.type, (err, result) ->
        if result
          cb(null, JSON.parse result)
        else
          cb(null, null)

  save: (type, data, cb) ->
    @getClient (err, client) =>
      str = JSON.stringify data
      client.set KEYS.type, str, (err) ->
        cb(err)
