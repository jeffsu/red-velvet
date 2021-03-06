express = require 'express'
config  = require '../config'
http    = require 'http'
path    = require 'path'
ROOT    = path.join(__dirname, '..', '..')

module.exports = () ->
 coffeescript = require('connect-coffee-script')
 app = express()
 app.configure ->
   app.set 'view engine', 'jade'
   app.set 'views', ROOT + '/views'
   app.use express.bodyParser()
   app.use app.router
   app.use coffeescript({ src: ROOT + '/public', prefix: '/public', force: true })
   app.use express.static(ROOT + '/public')

 app.get '/ping', (req, res) ->
   res.writeHead 200, {}
   res.end()

  app.get '/slides', (req, res) ->
   res.render 'slides'
 
 app.get '/layout', (req, res) ->
   layout = require(config.file)
   res.render "show-layout", { layout: layout }
