# A proxy object that exposes chainable methods that get deferred until later.
# - options:
#   - terminal:  Function names that accept a callback and terminate the chain
#   - circular:  Function names that return an object meant to be chained further
#   - deferral:  A function (realize) -> ... eventually calls realize(something),
#                which calls the chained methods upon something.
exports.deferral = (options) ->
  methodCalls = []
  proxy = {}
  if options.terminal?
    for termKey in options.terminal
      proxy[termKey] = ->
        methodCalls.append(key:
