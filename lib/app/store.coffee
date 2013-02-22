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

helpers     = require '../helpers'
Role        = require './role'
Broadcaster = require '../transport/broadcaster'

class Store extends Role
  constructor: (layout, @name, @options, cb) ->
    @options.partitions ||= 4096
    @options.hash       ||= helpers.djbHash
    @create_roles(layout)

    cb(this) if cb

  create_roles: (layout) ->
    for i in [0...@options.partitions]
      role_for_partition(layout, i)

  suffix_for: (id) ->
    "#{@name}:#{@options.hash(id) % @options.partitions}"

  key_for: (id) ->
    "store:#{@suffix_for id}"

  on_get: (cb) ->
    @get_handler = cb
    this

  on_set: (cb) ->
    @set_handler = cb
    this

  on_rm: (cb) ->
    @rm_handler = cb
    this

  on_migrate: (cb) ->
    @migrate_handler = cb
    this

  on_migration_cost: (cb) ->
    @migration_cost_handler = cb
    this

  get_migration_cost: (cb) ->
    @migration_cost_handler(cb)

  role_for_partition: (layout, index) ->
    layout.role "rv:store:#{@name}:#{index}", (role) =>
      # GET requests
      role.answer "rv:store-get:#{@name}:#{index}", (id, cb) =>
        @get_handler(id, cb)

      # SET/RM requests
      role.on "rv:store-set:#{@name}:#{index}", (id, value, cb) =>
        @set_handler(id, value, cb)

      role.on "rv:store-rm:#{@name}:#{index}", (id, cb) =>
        @rm_handler(id, cb)

  get: (sender, id, cb) ->
    sender.ask("rv:store-get:#{@suffix_for(id)}", {id: id}, cb)

  set: (sender, id, value, cb) ->
    sender.emit("rv:store-set:#{@suffix_for(id)}", {id: id, value: value}, cb)

  rm: (sender, id, cb) ->
    sender.emit("rv:store-rm:#{@suffix_for(id)}", {id: id}, cb)

  migrate_to: (hostports, packet) ->
    @migrate_handler new Broadcaster(hostports), (err) ->
      packet.ack(err)

module.exports = Role
