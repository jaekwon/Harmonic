#--
# Copyright (c) 2011 Jae Kwon 
#++

logger = require('nogg').logger('db.model')
mongo = require './mongo'
{deferral} = require '../utils'
{Validator} = require 'validator'
{Bnd, Bind, Fn} = require 'cardamom'
_ = require 'underscore'

# Just a wrapper around Validator to handle errors
# without throwing anything
class ModelValidator extends Validator
  constructor: (@model) ->
  error: (msg) ->
    (@model.errors[@fieldname] ||= []).push(msg)
  checkField: (@fieldname, message) ->
    return this.check(@model.data[@fieldname], message)
  checkOther: (value, message) ->
    @fieldname = null
    return this.check(value, message)

# A very light model base class around MongoDB.
# It's meant to be subclassed.
# 1. override collection
# 2. override the validate function
# NOTE: the validate function does not get called automatically
class @Model
  bnd = new Bnd this

  constructor: (@data) ->
    bnd.to this
    # fieldname -> error
    # for generic, null -> error
    @errors = {}
    @v = new ModelValidator(this)

  # override in your subclass
  collection: undefined

  # override in your subclass
  validate: ->
    # e.g. @v.checkField('text').len(3, 1024)

  # NOTE: does not validate.
  save: bnd Fn '[{options}?] [cb->]', (options, cb) ->
    this.withCollection (err, coll) =>
      return cb(err) if err? and cb?
      coll.insert @data, (err, it) =>
        cb(err, if err? undefined else this) if cb?

  # Get the underlying collection (instance method)
  # You can override the collection of a model instance
  #  by setting <Model>.collection .
  # - cb:    (err, coll) -> ...
  withCollection: bnd Fn '[{options}?] cb->', (options, cb) ->
    if not this.collection?
      throw new Error("Collection not defined for instance '#{this}'")
    mongo.withCollection _.extend({collection: this.collection}, options), cb

  toString: ->
    "<#{@constructor.name}>"

  # NOTE: does not validate.
  @create: Fn '{data} [{options}?] [cb->]', (data, options, cb) ->
    rec = new this(data)
    rec.save(options, cb)

  # Get the underlying collection
  # - cb:    (err, coll) -> ...
  @withCollection: Fn '[{options}?] cb->', (options, cb) ->
    if not this::collection?
      throw new Error("Collection not defined for model '#{this}'")
    mongo.withCollection _.extend({collection: this::collection}, options), cb

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
    modelClass = this
    dfrl = deferral
      terminal: ['toArray', 'forEach', 'next', 'count', 'size']
      circular: ['skip', 'limit', 'sort', 'map']
      deferral: (realize) ->
        modelClass.withCollection (err, coll) ->
          cursor = coll.find(query, options.fields)
          if options.limit?
            cursor = cursor.limit(options.limit)
          if options.skip?
            cursor = cursor.skip(options.skip)
          if options.sort?
            cursor = cursor.sort(options.sort)
          # convert pojos to instances of this model
          cursor = cursor.map (doc) ->
            new modelClass(doc)
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
