#--
# Copyright (c) 2011 Jae Kwon 
#++

mongo = require './mongo'
Validator = require('validator').Validator
ConnectionWrapper = require('./mongo_wrapper').ConnectionWrapper
logger = require('nogg').logger('db.model')

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
  @collection: undefined

  # override in your subclass
  validate: ->
    # e.g. @v.checkField('text').len(3, 1024)

  constructor: (@data) ->
    # fieldname -> error
    # for generic, null -> error
    @errors = {}
    @v = new ModelValidator(this)
    # the dict returned from mongodb after an update operation
    @_returnedData = undefined

  # NOTE: does not validate.
  save: (cb) ->
    this.coll (coll) =>
      coll.insert @data, {}, (err, it) =>
        @_returnedData = it
        if cb
          cb(err, if err? undefined else this)

  # NOTE: does not validate.
  @create: (data, cb) ->
    rec = new this(data)
    rec.save(cb)

  # Get the underlying collection
  @coll: (cb) ->
    if not @collection?
      throw new Error("collection not defined for model '#{this}'")
    mongo.with @collection, (coll) ->
      try
        wcoll = new ConnectionWrapper(coll, mongo.onError)
        cb(wcoll)
      catch err
        mongo.onError(err)

  # Get the underlying collection (instance method)
  coll: (cb) ->
    this.constructor.coll(cb)

  # Find exactly one.
  # If none or more than one is found, you'll get an error.
  # queryData: The query data as expected by node-mongodb-native.
  #             Or, a string to find by id.
  @findOne: (queryData, cb) ->
    _ModelClass = this
    this.coll (coll) ->
      coll.find(queryData).limit(2).toArray (err, items) ->
        if err?
          cb(err, null)
          return
        if items.length == 0
          cb(new Error("No models found for findOne"), null)
          return
        if items.length > 1
          cb(new Error("More than one model found for findOne"), null)
          return
        cb(null, new _ModelClass(items[0]))

exports.Model = Model