#--
# Copyright (c) 2011 Jae Kwon 
#++

config = require 'config'
logger = require('nogg').logger('harmonic.db.mongo')
Mongolian = require 'mongolian'
async = require 'async'
_ = require 'underscore'

# Configuration
do ->
  if config.database.uri
    parts = require('url').parse(config.database.uri)
    config.database.server_uri ||= (-> "#{@protocol}://#{@host}").call parts
    config.database.default_db ||= parts.pathname[1...] if not config.database.db?

# Create global server.
mongolian_logger = require('nogg').logger('harmonic.db.mongolian')
server = new Mongolian(config.database.server_uri,
  log:
    debug: mongolian_logger.debug
    info:  mongolian_logger.info
    warn:  mongolian_logger.warn
    error: mongolian_logger.error
)

# Close all databases.
# You need to call this for your program to exit.
exports.shutdown = ->
  server.close()
  logger.info "all mongo db connections shut down!"

# Ensure indices for all the given models
exports.ensure_indices_for = (models, callback) ->
  # For each model in series...
  async.forEach models, (model, next) ->
    if models.index?
      index_options = models.index
      if index_options instanceof Array
        [index, options] = index_options
      else
        [index, options] = [index_options, null]
      if '.' in models.collection
        [db_name, coll_name] = models.collection.split '.'
      else
        [db_name, coll_name] = [config.database.default_db, models.collection]
      collection = server.db(db_name).getCollection(coll_name)
      collection.ensureIndex index, options, next
  , (err, value) ->
    callback(err, value)
