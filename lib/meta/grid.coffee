config = require '../config'

# takes host, port, key, value
update_cell = """
  local namespace = "RV:GRID"
  local host      = KEYS[1]
  local port      = KEYS[2]
  local key       = KEYS[3]
  local value     = KEYS[4]

  local worker = host .. ":" .. port


  local grid_key = namespace .. ":" .. worker

  local len         = redis.call("LLEN", "RV:GRID:JOURNAL") + 1
  local journal_val = cjson.encode({ host = host, port = port, key = key, value = value, length = len })

  redis.call("HSET", grid_key, key, value)
  redis.call("LPUSH", "RV:GRID:JOURNAL", journal_val)
  redis.call("PUBLISH", "RV:GRID", journal_val)
  return redis.call("LLEN", "RV:GRID:JOURNAL")
"""

# take version
update_grid = """
  local len     = redis.call("LLEN", "RV:GRID:JOURNAL")
  local version = tonumber(KEYS[1])

  local delta = len - version
  if delta <= 0 then
    return {}
  else
    return redis.call("LRANGE", "RV:GRID:JOURNAL", 0, delta-1)
  end
"""

{EventEmitter} = require 'events'

class Grid extends EventEmitter
  constructor: ->
    @hosts   = {}
    @version = 0

  actAsForeman: ->
    config.getNewClient (err, client) =>
      client.subscribe "RV:GRID"
      client.on 'message', (ch, json) =>
        @play([ json ])
        
    @update()
    repeat = => @update()
    setTimeout repeat, 10000

  writeHash: (host, port, hash, cb) ->
    count = 0
    console.log hash
    for k,v of hash
      count++
      @write host, port, k, v, =>
        count--
    cb() if (cb && count == 0)

  write: (host, port, key, value, cb) ->
    config.getClient (err, client) =>
      client.eval update_cell, 4, host, port, key, value, (err, result) =>
        config.debug_log "written", err
        cb() if cb

  sync: (cb) ->
    config.getClient (err, client) =>
      client.keys "RV:GRID*", (err, keys) =>
        multi = client.multi()
        for key in keys
          multi.hgetall(key)
        multi.llen("RV:GRID:JOURNAL")
        multi.exec (err, hashes) =>
          @version = hashes.pop()
          @set_grid(keys, hashes)

          return cb(null) if (cb)
        
  set_grid: (keys, hashes) ->
    @hosts = {}

    for key, i in keys
      h = hashes[i]
      if m = key.match(/RV:GRID:(.+):(.+)/)
        nh = {}
        for k,v of h
          try
            nv = JSON.parse(v)
          catch e
            nv = v
          nh[k] = nv
        (@hosts[m[1]] ||= {})[m[2]] = nh

  update: (cb) ->
    config.getClient (err, client) =>
      client.eval update_grid, 1, @version, (err, results) =>
        config.debug_log "update grid", err, results
        if results && results.length
          @play(results, cb)
        else
          cb(null) if cb

  play: (results, cb) ->
    changedHosts = {}
    for json in results.reverse()
      hash = JSON.parse json
      changedHosts[hash.host] = true
      ((@hosts[hash.host] ||= {})[hash.port] ||= {})[hash.key] = hash.value
    cb(null) if cb

    if changedHosts[config.host]
      @emit "updated-host"

    @emit "updated"

module.exports = Grid
