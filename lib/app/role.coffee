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
    return if @assumed

    @assumed = true
    console.log "Assuming #{@name}"
    init = => @_init(app)
    setTimeout init, 3000

  canEmit: (event) ->
    return @ons[event]

  canAnswer: (q) ->
    return @answers[q]
   
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
