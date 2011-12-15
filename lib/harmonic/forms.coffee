#--
# Copyright (c) 2011 Jae Kwon 
# 
# NOT IMPLEMENTED YET
#++

config = require 'config'
logger = require('nogg').logger('harmonic.templates')
_ = require 'underscore'

# description
# label
# required
# validator 
Field = class exports.Field
  constructor: (options) ->
    _.extend(this, options)

# data
# prefix
# initial
Form = class exports.Form
  constructor: (options) ->
    _.extend(this, options)
