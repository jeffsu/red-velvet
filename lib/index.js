require('coffee-script')

module.exports.Layout  = require('./app/layout');
module.exports.Foreman = require('./system/foreman');
module.exports.helpers = require('./helpers');
var Broadcaster = require('./transport/broadcaster');
module.exports.getBroadcaster = function (list) { return new Broadcaster(list) };
