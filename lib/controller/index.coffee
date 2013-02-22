ConservativeMigrationStrategy = require './conservative-migration-strategy'
Client                        = require '../transport/client'

class Controller
  constructor: (strategy) ->
    @strategy = strategy || new ConservativeMigrationStrategy()

  control: (registration, graph, cb) ->
    # First get a list of foremen and overall specs. We use this list to figure
    # out how to allocate workers on machines.
    machines = {}
    clients  = {}
    for r in registration
      machines[r.ip] = r
      clients[r.ip]  = new Client(r.ip, r.port)

    new_graph = @strategy.optimize(machines, graph)

    # Now commit the graph. This involves first taking care of all migrations
    # (in parallel), then broadcasting the graph by invoking the callback. The
    # big invariant is that no alterations will ever happen to a running
    # worker; instead, we spin up a new one, give it a role, do a migration,
    # and commit the graph fully once the migration is finished.
    for ip, stuff of graph
      next_stuff = new_graph[ip]
      port_set   = {}
      for {port} in next_stuff
        port_set[port] = true

      # Any new instances? These will have ports that don't appear in the old
      # graph. Issue a spin-up request to each foreman.
      # TODO

module.exports = Controller
