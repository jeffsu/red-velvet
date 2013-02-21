www    = require '../transport/www'
config = require '../config'

class Controller
  constructor:  ->
    @www = www()
    @www.get '/', (req, res) ->
      req.render('controller')
    @www.listen(config.port + 1)
