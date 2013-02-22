require('coffee-script');
process.env['RV_TYPE'] = 'controller'
var config = require('../config')
config.start()

var Controller = require('./controller');
var ctrl = new Controller();
