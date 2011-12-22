assert = require 'assert'
_ = require 'underscore'

# A proxy object that exposes chainable methods that get deferred until later.
# - options:
#   - terminal:  Function names that accept a callback and terminate the chain
#   - circular:  Function names that return an object meant to be chained further
#   - deferral:  A function (realize) -> ... eventually calls realize(something),
#                which calls the chained methods upon something.
exports.deferral = (options) ->
  # Validations
  assert.ok options.terminal, 'You must specify at least one terminal function.'
  assert.ok options.deferral, 'You must specify the deferral method'
  assert.equal _.intersection(options.circular, options.terminal).length, 0, "Duplicate names: #{_.intersection(options.circular, options.terminal).join(', ')}"

  # Store method calls and args here,
  # a list of {key:, arguments:} or {key:, arguments}
  methodCalls = []

  # Define the 'realize' function,
  # where deferred calls really get called.
  realize = (object) ->
    current = object
    methodCalls.forEach (call) ->
      {key, args} = call
      assert.ok current[key], "Object does not contain the deferred method '#{key}'"
      current = current[key](args...)
      assert.ok current, "Deferred method '#{key}' did not return an object"

  # Define the proxy object which collects chain calls
  proxy = {}
  _.forEach options.circular, (circKey) ->
    proxy[circKey] = ->
      methodCalls.append(key: circKey, args: arguments)
      return proxy
  _.forEach options.terminal, (termKey) ->
    proxy[termKey] = ->
      methodCalls.append(key: termKey, args: arguments)
      # call deferral, hope 'realize' gets called.
      options.deferral(realize)
      return null
  
  return proxy
