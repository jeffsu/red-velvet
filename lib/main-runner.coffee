optimist = require 'optimist'
  
args = optimist
  .default
    port:  8000
    redis: 'redis://127.0.0.1:6379'
    env:   'local'
  .usage("rv [command] [options] [layout file]")
  .alias('r', 'redis')
  .describe('r', 'redis uri')

argv = args.argv

command = argv._[0]
file    = argv._[1]

if !command
  console.warn "Missing command."
  args.showHelp()
  process.exit()

else if !file
  console.warn "Missing file."
  args.showHelp()
  process.exit()

else if command == 'run'
  Foreman = require('../lib/system/foreman')
  forman = new Foreman file
  forman.runSteps()

else if command == 'layout'
  fullpath = process.cwd() + '/' + file
  layout = require fullpath
  layout.print()

