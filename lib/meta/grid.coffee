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

  redis.call("HSET", grid_key, key, value)

  if key == "version" then
    return redis.call("LLEN", "RV:GRID:JOURNAL")
  end

  local journal_val = cjson.encode({ host = host, port = port, key = key, value = value, length = len })
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
    @run()

  actAsForeman: ->
    # no op

  run: ->
    @sync()
    config.getNewClient (err, client) =>
      client.subscribe "RV:GRID"
      client.on 'message', (ch, json) =>
        @play([ json ])
        
    @update()
    repeat = => @update()
    setTimeout repeat, 10000

  writeHash: (host, port, hash, cb) ->
    count = 0
    for k,v of hash
      count++
      @write host, port, k, v, =>
        count--
    cb() if (cb && count == 0)

  activate: (host, port, cb)   -> @write host, port, 'status', 'active', cb
  deactivate: (host, port, cb) -> @write host, port, 'status', 'obsolete', cb
  destroy:  (host, port, cb) -> @write host, port, 'nuke', 'true', cb

  allocate: (host, port, roles, cb) ->
    @writeHash host, port, {roles: roles, type: 'worker', status: 'spinup'}, cb

  port_for: (host) ->
    port = config.port + 2
    port++ while @hosts[host] && @hosts[host][port]
    port

  write: (host, port, key, value, cb) ->
    config.getClient (err, client) =>
      client.eval update_cell, 4, host, port, key, JSON.stringify(value),
        (err, result) =>
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
          @emit "updated"

          return cb(null) if (cb)
        
  set_grid: (keys, hashes) ->
    @hosts = {}

    for key, i in keys
      h = hashes[i]
      if m = key.match(/RV:GRID:(.+):(.+)/)
        nh = {}
        for k,v of h
          nh[k] = JSON.parse v
        (@hosts[m[1]] ||= {})[m[2]] = nh

  update: (cb) ->
    config.getClient (err, client) =>
      client.eval update_grid, 1, @version, (err, results) =>
        console.log "update grid", err, results
        if results && results.length
          @play(results, cb)
        else
          cb(null) if cb

  toTable: ->
    table = []
    cols  = [ "type", "status" ]
    max   = 0

    for ip, host of @hosts
      row = [ ip ]
      table.push([ ip ])
      for port, hash of host
        for col in cols
          row.push(hash[col])
      max = Math.max(max, row.length-1)
    table.cols = max
    return table


     
  play: (results, cb) ->
    changedHosts = {}
    for json in results.reverse()
      hash = JSON.parse json
      changedHosts[hash.host] = true
      ((@hosts[hash.host] ||= {})[hash.port] ||= {})[hash.key] = JSON.parse(hash.value)
    cb(null) if cb

    if changedHosts[config.host]
      @emit "updated-self"

    @write config.host, config.port, 'version', @version
    @emit "updated"

  all_cells: (filter) ->
    result = []
    for host, row of @hosts
      for port, cell of row
        cell.host ||= host
        cell.port ||= port
        result.push cell if !filter || filter(cell, host, port)
    result

  foreman_for: (host) ->
    machine_row = @hosts[host]
    for port, cell of machine_row
      return cell if cell.type == 'foreman'

  workers_for: (host) ->
    machine_row = @hosts[host]
    (cell for port, cell of machine_row when cell.type == 'worker')

  all_foremen: -> @all_cells((cell) -> cell.type == 'foreman')
  all_workers: -> @all_cells((cell) -> cell.type == 'worker')

module.exports = Grid
