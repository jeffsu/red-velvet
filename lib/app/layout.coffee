Role  = require './role'
Store = require './store'
App   = require './app'

# builder for Layout
class Layout
  constructor: ->
    @roles  = {}
    @stores = {}

  role: (name, options, cb) ->
    if ! cb
      cb      = options
      options = {}

    throw new Error("Role: '#{name}' already exists") if name in @roles

    role = @roles[name] = new Role(name, options)
    cb(role)

    return this

  print: ->
    out = [ 'ROLES:' ]
    for name, role of @roles
      out.push "  #{name}"
      out.push "    partitins: #{role.partitions}"
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
    ret = []
    for name, role in @roles
      ret.push name
    ret

  getRolesFromEvent: (event) ->
    ret = []
    for name, role of @roles
      ret.push role if role.ons[event]
    ret

  getRoleFromQuestion: (question) ->
    for name, role of @roles
      return role if role.answers[question]
    
module.exports = Layout
