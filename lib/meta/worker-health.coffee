INTERVAL = 1000
class WorkerHealth
  constructor: (@clients) ->
    @delay = 0
    @startEventLoopChecking()
    @startClientChecking()

  startClientChecking: ->
    check = =>
      # do here
      process.send({ type: 'health', data: {} })

    setInterval(check, INTERVAL)

  startEventLoopChecking: ->
    start = Date.now()

    check = ->
      now = Date.now()
      @delay = Math.max(0, now - (a+INTERVAL))
      start = now

    setInterval(check, INTERVAL)
    
module.exports = WorkerHealth
