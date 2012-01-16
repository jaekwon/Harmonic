#--
# Copyright (c) 2011 Jae Kwon 
#++

config = require 'config'
logger = require('nogg').logger('harmonic.db.mongo')
Mongolian = require 'mongolian'
assert = require 'assert'

# Configuration
do ->
  if config.database.uri
    assert.ok(config.database.uri.indexOf('://') >= 0, "config.database.uri should include protocol://")
    parts = require('url').parse(config.database.uri)
    config.database.serverUri ||= (-> "#{@protocol}//#{@host}").call parts
    config.database.defaultDb ||= parts.pathname[1...] if not config.database.db?

# Global server reference.
_server = undefined

# Get Server
@withServer = withServer = (options, callback) ->
  if not _server?
    mongolianLogger = require('nogg').logger('harmonic.db.mongolian')
    _server = new Mongolian(config.database.serverUri,
      log:
        debug: mongolianLogger.debug
        info:  mongolianLogger.info
        warn:  mongolianLogger.warn
        error: mongolianLogger.error
    )
  callback(null, _server)

# Get Collection
# - options:
#   - collection: 'dbname.collname', or just 'collname'
@withCollection = withCollection = (options, callback) ->
  {collection} = options
  if '.' in collection
    [dbName, collName] = collection.split '.'
  else
    [dbName, collName] = [config.database.defaultDb, collection]

  withServer null, (err, server) ->
    return callback(err) if err?
    collection = server.db(dbName).collection(collName)
    callback(null, collection)

# Close all databases.
# You need to call this for your program to exit.
@shutdown = ->
  withServer null, (err, server) ->
    server.close()
    logger.info "All mongo db connections shut down!"

# Ensure indices for all the given model
# model:          A subclass of Model
#   collection:   The name of the collection
#   index:        List of ensureIndex args
@ensureIndicesFor = (model, callback) ->
  if model.index?
    indexOptions = model.index
    if indexOptions instanceof Array
      [index, options] = indexOptions
    else
      [index, options] = [indexOptions, null]
    withCollection {collection: model::collection}, (err, collection) ->
      return callback(err) if err?
      collection.ensureIndex index, options, (err) ->
        callback null, model.name
  else
    # HACK to get around https://github.com/marcello3d/node-mongolian/pull/67
    withCollection {collection: model::collection}, (err, collection) ->
      collection.indexes (err, indexes) ->
        callback null

# BSON types
for key in ['Long', 'ObjectId', 'Timestamp', 'DBRef'] # Binary, Code deprecated for now.
  @[key] = Mongolian[key]
