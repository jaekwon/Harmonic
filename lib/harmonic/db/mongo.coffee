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

# Create global server.
mongolianLogger = require('nogg').logger('harmonic.db.mongolian')
server = new Mongolian(config.database.serverUri,
  log:
    debug: mongolianLogger.debug
    info:  mongolianLogger.info
    warn:  mongolianLogger.warn
    error: mongolianLogger.error
)

# Close all databases.
# You need to call this for your program to exit.
exports.shutdown = ->
  server.close()
  logger.info "all mongo db connections shut down!"

# Ensure indices for all the given model
# model:          A subclass of Model
#   collection:   The name of the collection
#   index:        List of ensureIndex args
exports.ensureIndicesFor = (model, callback) ->
  if model.index?
    indexOptions = model.index
    if indexOptions instanceof Array
      [index, options] = indexOptions
    else
      [index, options] = [indexOptions, null]
    if '.' in model.collection
      [dbName, collName] = model.collection.split '.'
    else
      [dbName, collName] = [config.database.defaultDb, model.collection]
    collection = server.db(dbName).getCollection(collName)
    collection.ensureIndex index, options, callback
  else
    callback(null, null)
