Role  = require './role'
#Store = require './store'
App   = require './app'

# builder for Layout
class Layout
  constructor: ->
    @roles  = {}
    @stores = {}

    @emitsLookup = {}
    @asksLookup  = {}

  role: (name, cb) ->
    throw new Error("Role: '#{name}' already exists") if name in @roles

    role = @roles[name] = new Role(name)
    cb(role)

    for name, event of role.ons
      (@emitsLookup[name] ||= []).push(role.name)


    for name, event of role.answers
      (@asksLookup[name] ||= []).push(role.name)

    return this

  store: (name, options, cb) ->
    throw new Error("Store: '#{name}' already exists") if name in this
    @stores[name] = this[name] = new Store(this, name, options, cb)
    return this

  print: ->
    out = [ 'ROLES:' ]
    for name, role of @roles
      out.push "  #{name}"
      @printRole role, out
    console.log out.join("\n")
        
  printRole: (role, out) ->
    out.push  "    listens:"

    i = 0
    for name of role.ons
      i++
      out.push "      o " + name

    out.pop() if i == 0

    out.push  "    answers:"

    i = 0
    for name of role.answers
      i++
      out.push "      o " + name

    out.pop() if i == 0

   

  getRole: (name) ->
    @roles[name]

  getRoleNames: ->
    return @roleNames if @roleNames

    @roleNames = []
    @roleNames.push name for name, r of @roles
    return @roleNames


  getRoleNamesFromEmit: (emit) ->
    return @emitsLookup[emit]

  getRoleNameFromAsk: (ask) ->
    return @asksLookup[ask][0]
    
    
module.exports = Layout
