var rv = require('../lib')

var layout = new rv.Layout()
layout
  .role('line-producer', function (role) {
    role.init(function (app) {
      function line() {
        app.emit('line', 'hello world');
      }

      setInterval(line, 1000);

      function ask() {
        console.log('asking word-count');
        app.ask('word-count', 'hello', function (err, answer) {
          console.log('answer: ' + answer);
        });
      }
      setInterval(ask, 3000);
    });
  })

  .role('line-reader', function (role) {
    role.on('line', function (packet, app) { 
      console.log('----------------->line')
      app.emit('words', packet.data.split(/\s+/));
      packet.ack();
    });
  })

  .role('word-counter', function (role) {
    var counts = {};

    role.on('words', function (packet, app) {
      console.log('--------------->words')
      var words = packet.data;
      console.log("got words", words);
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

  .store('word-store', function (store) {
    store.partitions   = 1000;
    store.hashFunction = rv.helpers.djbHash;

    store.on('get', function (packet) {
      var key = packet.key;
      packet.reply('data');
    })

    store.on('set', function (packet) {
      var key   = packet.key;
      var value = packet.value;
      packet.ack(null);
    })

    store.on('delete', function (packet) {
      var key = packet.key;
      packet.ack(null);
    })

  })

module.exports = layout;
