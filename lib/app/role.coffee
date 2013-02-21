# node inside of topology
class Role
  constructor: (@name) ->
    @ons     = {}
    @answers = {}

  init: (cb) ->
    @_init = cb

  _init: (app) ->
    # default, nothing

  on: (name, opts, cb) ->
    if !cb
      cb   = opts
      opts = {}

    cb.opts = opts
    @ons[name] = cb

  answer: (name, opts, cb) ->
    if !cb
      cb   = opts
      opts = {}

    cb.opts = opts
    @answers[name] = cb

  migrate_to: (hostport, packet) ->
    # Default: do nothing; ack immediately
    packet.ack()

  get_migration_cost: (cb) ->
    # Assume zero migration cost unless otherwise specified. Migration cost is
    # measured as a linear factor of bytes. This function will be called fairly
    # frequently.
    cb(0)

module.exports = Role
