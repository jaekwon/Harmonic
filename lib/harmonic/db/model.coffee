#--
# Copyright (c) 2011 Jae Kwon 
#++

logger = require('nogg').logger('db.model')
mongo = require './mongo'
{deferral} = require '../utils'
{Validator} = require 'validator'

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
class Model

  # so we know that subclasses inherit from Model
  _modelPrototype: 'epytotorPlodem_'

  # override in your subclass
  collection: undefined

  # override in your subclass
  validate: ->
    # e.g. @v.checkField('text').len(3, 1024)

  constructor: (@data) ->
    # fieldname -> error
    # for generic, null -> error
    @errors = {}
    @v = new ModelValidator(this)

  # NOTE: does not validate.
  save: (cb) ->
    this.withCollection (err, coll) =>
      return cb(err) if err? and cb?
      coll.insert @data, {}, (err, it) =>
        cb(err, if err? undefined else this) if cb?

  # NOTE: does not validate.
  @create: (data, cb) ->
    rec = new this(data)
    rec.save(cb)

  # Get the underlying collection
  # - cb:    (err, coll) -> ...
  @withCollection: (cb) ->
    if not this::collection?
      throw new Error("Collection not defined for model '#{this}'")
    mongo.withCollection {collection: this::collection}, cb

  # Get the underlying collection (instance method)
  # You can override the collection of a model instance
  #  by setting <Model>.collection .
  # - cb:    (err, coll) -> ...
  withCollection: (cb) ->
    if not this.collection?
      throw new Error("Collection not defined for instance '#{this}'")
    mongo.withCollection {collection: this.collection}, cb

  # Find query method
  # - query:      The query filter.
  # - options:
  #   - fields:   Set of fields to return.
  #   - limit:    Limit to this many results
  #   - skip:     Skip this many results
  #   - sort:     Sort object
  # Returned object has methods:
  #   - toArray(callback)
  #   - forEach(func, callback)
  #   - next(callback)
  #   - count(callback) // ignores skip/limit
  #   - size(callback)  // honors skip/limit
  #   - skip, limit, sort
  @find: (query, options) ->
    deferral
      terminal: ['toArray', 'forEach', 'next', 'count', 'size']
      circular: ['skip', 'limit', 'sort', 'map']
      deferral: (realize) =>
        this.withCollection (err, coll) ->
          cursor = coll.find(query, options.fields)
          if options.limit?
            cursor = cursor.limit(options.limit)
          if options.skip?
            cursor = cursor.skip(options.skip)
          if options.sort?
            cursor = cursor.sort(options.sort)
          # convert pojos to instances of this model
          cursor = cursor.map (doc) -> new this(doc)
          # do onto cursor what was done onto the deferral
          realize(cursor)

exports.Model = Model
