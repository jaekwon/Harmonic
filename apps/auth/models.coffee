#--
# Copyright (c) 2011 Jae Kwon 
#++

config = require 'config'
harmonic = require 'harmonic'

class exports.User extends harmonic.db.Model
  @collection: 'user'

  validate: ->
    # e.g. @v.checkField('text').len(3, 1024)
