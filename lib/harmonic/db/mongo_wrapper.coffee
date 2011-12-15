#--
# Copyright (c) 2011 Jae Kwon 
# MIT License
#++

mongodb = require('mongodb')
assert = require('assert')

# if the last arg is a function,
# wraps the function so it never throws an error,
# but rather calls errcb.
make_arguments_safe = (args, errcb) ->
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
      return @conn.find(make_arguments_safe(arguments, @errcb)...)
    else
      return new exports.CursorWrapper(@conn.find(arguments...), @errcb)

  # bind all the other methods
  for method_name, method of mongodb.Collection.prototype
    do (method_name, method) =>
      if method_name == 'find' then return
      this::[method_name] = ->
        method.apply(@conn, make_arguments_safe(arguments, @errcb))

class exports.CursorWrapper
  constructor: (@cursor, @errcb) ->

  # these functions are terminal
  for method_name in ['toArray', 'each', 'count', 'nextObject', 'getMore', 'explain']
    do (method_name) =>
      this::[method_name] = ->
        return @cursor[method_name].apply(@cursor, make_arguments_safe(arguments, @errcb))

  # these functions return another cursor, so the return object
  # needs to be re-wrapped
  for method_name in ['sort','limit','skip','batchSize']
    do (method_name) =>
      this::[method_name] = ->
        return new CursorWrapper(@cursor[method_name].apply(@cursor, arguments), @errcb)
