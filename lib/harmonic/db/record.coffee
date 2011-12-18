#--
# Copyright (c) 2011 Jae Kwon 
#++

mongo = require './mongo'
Validator = require('validator').Validator
ConnectionWrapper = require('./mongo_wrapper').ConnectionWrapper
logger = require('nogg').logger('db.record')

# Just a wrapper around Validator to handle errors
# without throwing anything
class RecordValidator extends Validator
  constructor: (@record) ->
  error: (msg) ->
    (@record.errors[@fieldname] ||= []).push(msg)
  check_field: (@fieldname, message) ->
    return this.check(@record.data[@fieldname], message)
  check_other: (value, message) ->
    @fieldname = null
    return this.check(value, message)

# A very light model base class around MongoDB.
# It's meant to be subclassed.
# 1. override collection
# 2. override the validate function
# NOTE: the validate function does not get called automatically
class Record

  # override in your subclass
  @collection: undefined

  # override in your subclass
  validate: ->
    # e.g. @v.check_field('text').len(3, 1024)

  constructor: (@data) ->
    # fieldname -> error
    # for generic, null -> error
    @errors = {}
    @v = new RecordValidator(this)
    # the dict returned from mongodb after an update operation
    @_returned_data = undefined

  # NOTE: does not validate.
  save: (cb) ->
    this.coll (coll) =>
      coll.insert @data, {}, (err, it) =>
        @_returned_data = it
        if cb
          cb(err, if err? undefined else this)

  # NOTE: does not validate.
  @create: (data, cb) ->
    rec = new this(data)
    rec.save(cb)

  # Get the underlying collection
  @coll: (cb) ->
    if not @collection?
      throw new Error("collection not defined for record '#{this}'")
    mongo.with @collection, (coll) ->
      try
        wcoll = new ConnectionWrapper(coll, mongo.on_error)
        cb(wcoll)
      catch err
        mongo.on_error(err)

  # Get the underlying collection (instance method)
  coll: (cb) ->
    this.constructor.coll(cb)

  # Find exactly one.
  # If none or more than one is found, you'll get an error.
  # query_data: The query data as expected by node-mongodb-native.
  #             Or, a string to find by id.
  @findOne: (query_data, cb) ->
    _RecordClass = this
    this.coll (coll) ->
      coll.find(query_data).limit(2).toArray (err, items) ->
        if err?
          cb(err, null)
          return
        if items.length == 0
          cb(new Error("No records found for findOne"), null)
          return
        if items.length > 1
          cb(new Error("More than one record found for findOne"), null)
          return
        cb(null, new _RecordClass(items[0]))

exports.Record = Record
