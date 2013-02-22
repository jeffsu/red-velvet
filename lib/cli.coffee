optimist = require 'optimist'
  
console.log 'loading config'
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
      clean   clears existing Redis data
              (useful if your network layout has changed)
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

else if !file && command != 'clean'
  console.warn "Missing file."
  args.showHelp()
  process.exit()

fullpath = "#{process.cwd()}/#{file}"
env      = process.env
env.RV_FILE  = fullpath
env.RV_PORT  = argv.port
env.RV_REDIS = argv.redis
env.RV_ENV   = argv.env

config = require './config'
config.start()

console.log `"\033[1;31m"` + """
  ____  ____  ____    _  _  ____  __    _  _  ____  ____ 
 (  _ \\(  __)(    \\  / )( \\(  __)(  )  / )( \\(  __)(_  _)
  )   / ) _)  ) D (  \\ \\/ / ) _) / (_/\\\\ \\/ / ) _)   )(  
 (__\\_)(____)(____/   \\__/ (____)\\____/ \\__/ (____) (__) 
""" + `"\033[0;0m"`

switch command
  when 'run'
    Foreman = require '../lib/system/foreman'
    forman = new Foreman
    forman.run()

  when 'layout'
    layout = require fullpath
    layout.print()

  when 'clean'
    config.getClient (err, client) ->
      client.keys 'RV:*', (err, keys) ->
        multi = client.multi()
        for k in keys
          multi.del k
        multi.exec (err) ->
          console.log "finished"
          client.end()
          process.exit()


  else
    args.showHelp()
