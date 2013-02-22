require('coffee-script')
config = require('../config');
config.start();
var Worker = require('./worker')
var worker = new Worker();
