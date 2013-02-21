red-velvet
==========

Distributed Framework Playground for Node.js

```javascript
var rv = require('red-velvet')

var layout = new rv.Layout()
layout
  .role('line-producer', function (role) {
    role.init(function (app) {
      function line() {
        app.emit('line', 'hello world');
      }

      setInterval(line, 1000);

      function ask() {
        app.ask('word-count', 'hello', function (err, answer) {
          console.log('answer: ' + answer);
        });
      }

      setInterval(ask, 3000);
    });
  })

  .role('line-reader', function (role) {
    role.on('line', function (packet, app) { 
      app.emit('words', packet.data.split(/\s+/));
      packet.ack();
    });
  })

  .role('word-counter', function (role) {
    var counts = {};

    role.on('words', function (packet, app) {
      var words = packet.data;
      for (var i=0; i<words.length; i++) {
        var word = words[i];
        counts[word] = (counts[word] || 0) + 1;
      }
      packet.ack();
    });

    role.answer('word-count', function (packet, app) {
      var word = packet.data;
      packet.answer(null, counts[word] || 0);
    });
  })

module.exports = layout;
```
