Grid = require './grid'

grid = new Grid()
console.log 'sync'
grid.sync ->
  console.log grid.hosts
  grid.write 'localhost', 8001, 'foo', 'bar', ->
    console.log 'yay'
    grid.write 'localhost', 8001, 'foo', 'bar2', ->
      grid.update ->
        console.log "update->", grid.hosts
