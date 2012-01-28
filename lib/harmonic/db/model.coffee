#--
# Copyright (c) 2011 Jae Kwon 
#++

logger = require('nogg').logger('db.model')
mongo = require './mongo'
{deferral} = require '../utils'
{Validator} = require 'validator'
{B, Fn} = require 'cardamom'
async = require 'async'
{ErrorBase, eventful} = require 'cardamom'
{EventEmitter} = require 'events'
_ = require 'underscore'

# A very light model base class around MongoDB.
# It's meant to be subclassed.
# NOTE: the validate function does not get called automatically
class @Model extends EventEmitter
  eventful this

  constructor: (@data) ->
    # { fieldname: [error...] } if there is an error.
    # for generic, { null: [error...] }
    # null, if no errors.
    @errors = null
    @v = new ModelValidator(this)

  # override in your subclass
  @collection: undefined

  # helper to declare indices
  @index: (index, options=undefined) ->
    if @indices?.class isnt this
      @indices ||= []
      @indices.class = this
    @indices.push index: index, options: options

  # override in your subclass
  validate: ->
    # e.g. @v.checkField('text').len(3, 1024)

  # NOTE: does not validate.
  save:B Fn '[{options}?] [cb->]', (options, cb) ->

    # Call beforeCreate, then beforeSave.
    # Call cb(err) if error,
    # Fall back to <Model>#error then Model#error.
    isNew = not @data._id?
    try
      try
        @constructor.emit 'beforeCreate', this, options if isNew
        @emit 'beforeSave', this, options
      catch error
        try return cb error if cb?
        return @emit 'error', error
    catch error
      return @constructor.emit 'error', error

    # Save
    @constructor.withCollection (err, coll) =>
      return cb(err) if err? and cb?
      coll.insert @data, (err, it) =>
        return cb err if err?

        # Call cb, then afterSave, then afterCreate.
        # Stop if any raise an error.
        # Fall back to <Model>#error, then Model#error.
        try
          try
            cb(null, this) if cb?
            @emit 'afterSave', this, it
            @constructor.emit 'afterCreate', this, it if isNew
          catch error
            return @emit 'error', error
        catch error
          return @constructor.emit 'error', error

  toString: ->
    "<#{@constructor.name}>"

  # NOTE: does not validate.
  @create: Fn '{data} [{options}?] [cb->]', (data, options, cb) ->
    rec = new this(data)
    rec.save(options, cb)

  # Get the underlying collection
  # - cb:    (err, coll) -> ...
  @withCollection: Fn '[{options}?] cb->', (options, cb) ->
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
  @find: Fn '{query} [{options}] [callback->]', (query, options={}, callback) ->
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
  @findOne: (query, callback) ->
    if (typeof query) == 'string'
      query = {_id: new mongo.ObjectId(query)}
    @find(query, limit: 2).toArray (err, arr) =>
      if arr.length != 1
        return callback(new Error("#{this}.findOne expected 1 result but got #{arr.length}"), null)
      callback(null, arr[0])

  @toString: ->
    "class:#{@name}"

  # Ensure indices, as defined optionally by (Model).indices,
  @ensureIndices: (callback) ->

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

  B.ind @

# Just a wrapper around Validator to handle errors
# without throwing anything
class ModelValidator extends Validator
  constructor: (@model) ->
  error: (msg) ->
    ( ( @model.errors ||= {} )[@fieldname] ||= [] ).push(msg)
  checkField: (@fieldname, message) ->
    return this.check(@model.data[@fieldname], message)
  checkOther: (value, message) ->
    @fieldname = null
    return this.check(value, message)

inspect = require('util').inspect
class @ValidationError extends ErrorBase
  constructor: (@errors) ->
    super(require('util').inspect(@errors))
  
  toString: -> "ValidationError: #{@message}"
