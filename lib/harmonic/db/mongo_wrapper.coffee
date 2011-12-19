#--
# Copyright (c) 2011 Jae Kwon 
#++

assert = require('assert')

# if the last arg is a function,
# wraps the function so it never throws an error,
# but rather calls errcb.
makeArgumentsSafe = (args, errcb) ->
  # TODO this doesn't work in some javascript engines, me don't think.
  if typeof(args[args.length-1]) == 'function'
    cb = args[args.length-1]
    args[args.length-1] = ->
      try
        cb.apply(null, arguments)
      catch err
        errcb(err)
  return args

# responsible for wrapping a node-mongodb-native connection
# and making sure errors raised in user callbacks don't bork the whole system.
class exports.ConnectionWrapper
  constructor: (@conn, @errcb) ->

  # if find is called with a function, simply wrap
  find: ->
    errcb = @errcb
    if typeof(arguments[arguments.length-1]) == 'function'
      return @conn.find(makeArgumentsSafe(arguments, @errcb)...)
    else
      return new exports.CursorWrapper(@conn.find(arguments...), @errcb)

  # bind all the other methods
  #for methodName, method of mongodb.Collection.prototype
  #  do (methodName, method) =>
  #    if methodName == 'find' then return
  #    this::[methodName] = ->
  #      method.apply(@conn, makeArgumentsSafe(arguments, @errcb))

class exports.CursorWrapper
  constructor: (@cursor, @errcb) ->

  # these functions are terminal
  for methodName in ['toArray', 'each', 'count', 'nextObject', 'getMore', 'explain']
    do (methodName) =>
      this::[methodName] = ->
        return @cursor[methodName].apply(@cursor, makeArgumentsSafe(arguments, @errcb))

  # these functions return another cursor, so the return object
  # needs to be re-wrapped
  for methodName in ['sort','limit','skip','batchSize']
    do (methodName) =>
      this::[methodName] = ->
        return new CursorWrapper(@cursor[methodName].apply(@cursor, arguments), @errcb)
