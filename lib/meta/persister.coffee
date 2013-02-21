redis = require 'redis'

class Persister
  constructor: (@uri) ->
    @client = redis.createClient(@uri) ->

  saveHealth: (host, data, cb) ->
    cb(null)

  getCluster: (cb) ->
    cb(null, null)

  getAllHealth: (data, cb) ->
    cb(null, [])


module.exports = Persister
