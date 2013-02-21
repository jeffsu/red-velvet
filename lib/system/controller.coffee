www    = require '../transport/www'
config = require '../config'

class Controller
  constructor:  ->
    @www = www()
    @www.get '/', (req, res) ->
      res.render('controller', controller: config)

    @www.listen(config.port + 1)

module.exports = Controller
