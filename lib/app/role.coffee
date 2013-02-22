# node inside of topology
class Role
  constructor: (@name, @options, @cb) ->
    @ons     = {}
    @answers = {}
    @cb(this)

    @partitions = @options.partitions || 1
    @hash       = @options.hash       || -> 0
    @assumed = false

  getPartition: (data) ->
    @hash(data)

  assume: (app) ->
    @_init(app) if @_init && @assumed == false
    @assumed = true

   
  load: ->
    @cb(this) if @cb
    
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
