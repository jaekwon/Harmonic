#--
# Copyright (c) 2011 Jae Kwon 
#++

logger = require('nogg').logger('db.model')
mongo = require './mongo'
{deferral} = require '../utils'
amanda = require 'amanda'
{clazz, Fn} = require 'cardamom'
async = require 'async'
_ = require 'underscore'

# A very light model base class around MongoDB.
# It's meant to be subclassed.
# NOTE: the validate function does not get called automatically
@Model = clazz 'Model', ->

  # Override
  @collection = undefined
  @schema = undefined

  # Helper to declare indices
  @index = (index, options=undefined) ->
    if @indices?.class isnt this
      @indices ||= []
      @indices.class = this
    @indices.push index: index, options: options

  # Helper to create a new object
  @create = Fn '{data} [{options}?] [cb->]', (data, options, cb) ->
    rec = new this(data)
    rec.save(options, cb)

  # Get the underlying collection
  # - cb:    (err, coll) -> ...
  @withCollection = Fn '[{options}?] cb->', (options, cb) ->
    if not @collection?
      throw new Error("Collection not defined for model '#{this}'")
    mongo.withCollection _.extend({collection: @collection}, options), cb

  # Find query method
  # - query:      The query filter.
  # - options:
  #   - fields:   Set of fields to return.
  #   - limit:    Limit to this many results
  #   - skip:     Skip this many results
  #   - sort:     Sort object
  #
  # Returned object has methods:
  #   - toArray(callback)
  #   - forEach(func, callback)
  #   - next(callback)
  #   - count(callback) // ignores skip/limit
  #   - size(callback)  // honors skip/limit
  #   - skip, limit, sort
  @find = Fn '{query} [{options}] [callback->]', (query, options={}, callback) ->
    dfrl = deferral
      terminal: ['toArray', 'forEach', 'next', 'count', 'size']
      circular: ['skip', 'limit', 'sort', 'map']
      deferral: (realize) =>
        @withCollection (err, coll) =>
          cursor = coll.find(query, options.fields)
          if options.limit?
            cursor = cursor.limit(options.limit)
          if options.skip?
            cursor = cursor.skip(options.skip)
          if options.sort?
            cursor = cursor.sort(options.sort)
          # convert pojos to instances of this model
          cursor = cursor.map (doc) =>
            new @(doc)
          # do onto cursor what was done onto the deferral
          realize(cursor)
    if callback?
      return dfrl.toArray(callback)
    dfrl

  # Find (and expect) just one.
  # - query:    The query filter, or an _id string.
  # - callback: A callback(err, <Model>) ->
  @findOne = (query, callback) ->
    if (typeof query) == 'string'
      query = {_id: new mongo.ObjectId(query)}
    @find(query, limit: 2).toArray (err, arr) =>
      if arr.length != 1
        return callback(new Error("#{this}.findOne expected 1 result but got #{arr.length}"), null)
      callback(null, arr[0])

  @toString = -> "<ModelClass #{@name}>"

  # Ensure indices, as defined optionally by (Model).indices,
  @ensureIndices = (callback) ->
    if not @indices?
      # HACK to get around https://github.com/marcello3d/node-mongolian/pull/67
      @withCollection {collection: @collection}, (err, collection) ->
        collection.indexes (err, indexes) ->
          callback null
      return
    async.forEachSeries @indices, (inOp, next) =>
      @withCollection {collection: @collection}, (err, collection) =>
        return callback(err) if err?
        collection.ensureIndex inOp.index, inOp.options, (err) ->
          next(err)
    , (err) ->
      callback err

  init: (@data) ->
  # Override, or define the @schema property.
  # cb takes (err)
  # see https://github.com/Baggz/Amanda#error for format.
  validate: (cb) ->
    if @constructor.schema?
      schema =
        type: 'object'
        properties: @constructor.schema
      amanda.validate @data, schema, cb
    else
      cb(null)
  save$: Fn '[{options}?] [cb->]', (options, cb) ->
    @constructor.withCollection (err, coll) =>
      return cb(err) if err? and cb?
      coll.insert @data, (err, it) =>
        return cb err if err?
  toString: ->
    "<#{@constructor.name}>"
