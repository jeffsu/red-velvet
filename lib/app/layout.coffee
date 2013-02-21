Role = require './role'
App  = require './app'

# builder for Layout
class Layout
  constructor: ->
    @roles = {}

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
