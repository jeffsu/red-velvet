optimist = require 'optimist'
  
args = optimist
args = args.default
  port:  8000
  redis: 'redis://127.0.0.1:6379'
  env:   'local'

args = args.usage """
    Red Velvet: 0.0.0 (Jeff Su, Spencer Tipping, Forrest Cao)
    rv [command] [options] [layout file]

    Commands: 
      run     starts redvelvet
      layout  prints out the layout tree
    """

args = args
  .alias('r', 'redis')
  .describe('redis', 'redis uri')

  .alias('p', 'port')
  .describe('port', 'base port: foreman [port], controller [port+1], workers [port+2...port+n+2]')

  .alias('e', 'env')
  .describe('env', 'environment to run red-velvet')


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

fullpath     = "#{process.cwd()}/#{file}"
config       = require './config'
config.file  = fullpath
config.port  = argv.port
config.redis = argv.redis
config.env   = argv.env
config.layout = require fullpath

switch command
  when 'run'
    Foreman = require '../lib/system/foreman'
    forman = new Foreman
    forman.run()

  when 'layout'
    layout = require fullpath
    layout.print()

  else
    args.showHelp()
