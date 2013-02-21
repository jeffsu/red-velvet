# A store is a user-facing layer above a series of virtual roles (one for each
# data partition). It supports the following methods:
#
#   store.get('id', callback)
#   store.set('id', value, callback)
#   store.rm('id', callback)
#
# It creates one role per partition, so for instance, layout.store('user')
# would produce:
#
#   store:user-0
#   store:user-1
#   ...
#   store:user-4095
#
# The number of partitions can be set as one of the options.

helpers = require '../helpers'

class Store extends Role
  constructor: (app, layout, @name, @options, cb) ->
    @app = app
    @options.partitions ||= 4096
    @options.hash       ||= helpers.djbHash
    @create_roles(layout)

    cb(this) if cb

  create_roles: (layout) ->
    for i in [0...@options.partitions]
      role_for_partition(layout, i)

  suffix_for: (id) ->
    "#{@name}:#{@options.hash(id) % @options.partitions}"

  on_get: (cb) ->
    @get_handler = cb
    this

  on_set: (cb) ->
    @set_handler = cb
    this

  on_rm: (cb) ->
    @rm_handler = cb
    this

  on_migration_cost: (cb) ->
    @migration_cost = cb
    this

  get_migration_cost: (cb) ->
    @migration_cost(cb)

  role_for_partition: (layout, index) ->
    layout.role "store:#{@name}:#{index}", (role) =>
      # GET requests
      role.answer "store-get:#{@name}:#{index}", (id, cb) =>
        @get_handler(id, cb)

      # SET/RM requests
      role.on "store-set:#{@name}:#{index}", (id, value, cb) =>
        @set_handler(id, value, cb)

      role.on "store-rm:#{@name}:#{index}", (id, cb) =>
        @rm_handler(id, cb)

  get: (id, cb) ->
    @app.ask("store-get:#{@suffix_for(id)}", {id: id}, cb)

  set: (id, value, cb) ->
    @app.emit("store-set:#{@suffix_for(id)}", {id: id, value: value}, cb)

  rm: (id, cb) ->
    @app.emit("store-rm:#{@suffix_for(id)}", {id: id}, cb)

module.exports = Role
