#--
# Copyright (c) 2011 Jae Kwon 
#++

config = require 'config'
logger = require('nogg').logger('harmonic.db.mongo')
{Db, Connection, Server} = require('mongodb')
async = require 'async'
_ = require 'underscore'

# All databases. {"dbname": <Db>}
open_dbs = {}
# All collections. {"dbname.collname": <Connection>}
open_collections = {}
# List of callbacks to call after database opens. {"dbname.collname": [callbacks]}
open_callbacks = {}

# Main callback for after opening any db (and all of its collections)
# name: "dbname"
did_open_db = (name, db) ->
  logger.debug "opened db '#{name}': #{db?}"
  open_dbs[name] = db

# Main callback for after opening any collection
# name: "dbname.collname"
did_open_collection = (name, coll) ->
  logger.debug "opened collection '#{name}': #{coll?}"
  open_collections[name] = coll
  while open_callbacks[name]?.length > 0
    callback = open_callbacks[name].shift()
    callback(coll)

# Ensure that collection is available for the callback. (async or sync)
# e.g.
# mongo = require 'mongo'
# mongo.with 'dbname.collname', (coll) ->
#  ...
exports.with = (name, cb) ->
  if open_collections[name]?
    cb(open_collections[name])
  else
    logger.debug "pushing callback for '#{name}'"
    (open_callbacks[name] ||= []).push(cb)

# Close all databases.
# You need to call this for your program to exit.
exports.shutdown = ->
  for dbname, db of open_dbs
    db.close()
  logger.info "all mongo db connections shut down!"

# Ensures that init happened.
initialized = false
exports.with_init = (cb) ->
  if initialized
    cb(null, null)
  else
    init(cb)

# TODO Document
exports.on_error = (err) ->
  try
    logger.error "db/mongo caught an exception."
    logger.error err.message
    logger.error err.stack
  catch e
    console.log e

# Private initialization method.
# Use 'with_init' instead.
init = (cb) ->
  # For each dbname in parallel...
  async.forEach _.keys(config.mongo.dbs), (dbname, next) ->
    dbsettings = config.mongo.dbs[dbname]
    server = new Server(config.mongo.host, config.mongo.port, {})
    db = new Db(dbname, server, {native_parser: false})
    db.open (err, db) ->
      if err?
        logger.error "error in opening db '#{dbname}': #{err}"
        return next(err)

      # attach an error listener... 
      # if not, the server instance can blow up with a global exception.
      # also, node-mongodb-native wraps the err in err.message.
      db.on 'error', (err) -> exports.on_error(err.message)

      # For each collection in series...
      async.forEachSeries _.keys(dbsettings), (collname, next) ->
        indices = dbsettings[collname]
        return next() if not indices?
        # open collection...
        db.collection collname, (err, coll) ->
          if err?
            logger.error "error in opening collection '#{collname}': #{err}"
            return next(err)

          # For each index in series...
          async.forEachSeries indices, ([index, option], next) ->
            coll.ensureIndex index, option, (err, indexName) ->
              if err?
                logger.error "error in ensuring index '#{indexName}': #{err}"
                return next(err)
              logger.info "ensured index: #{indexName} -> #{JSON.stringify(index)}, #{JSON.stringify(option)}"
              next(null, indexName)

          # ... after all indices are processed...
          , (err, indexNames) ->
            return next(err) if err?
            # ... call did_open_collection
            did_open_collection("#{dbname}.#{collname}", coll)
            next(null, collname)

      # ... after all collections are processed...
      , (err, collnames) ->
        return next(err) if err?
        # ... call did_open_db
        did_open_db(dbname, db)
        next(null, dbname)

  # ... after all databases are opened and processed...
  , (err, dbnames) ->
    cb(err, dbnames) if cb?
