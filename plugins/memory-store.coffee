# Sets up an in-memory store. Use like this:
# memory_store = require 'plugins/memory-store'
# app.store('foo', (store) ->
#   memory_store(store)

module.exports = (store) ->
  elements = {}

  store.on_get (id, cb) -> cb(null, elements[id])
  store.on_set (id, value, cb) ->
    elements[id] = value
    cb(null)

  store.on_rm (id, cb) ->
    delete elements[id]
    cb(null)

  store.on_migration_cost (cb) ->
    # TODO: fix this for serious applications
    cb(0)

  store.on_migrate (sender, cb) ->
    count = 0
    for k, v in elements
      count++
      store.set sender, k, v, (err) ->
        count--
        cb(null) if count == 0
