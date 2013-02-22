# node inside of topology
class Role
  constructor: (@name, @options) ->
    @ons     = {}
    @answers = {}

    @partition = @options.partitions || 1
    @hash      = @options.hash       || -> 0

  getPartition: (data) ->
    @hash(data)

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

module.exports = Role
