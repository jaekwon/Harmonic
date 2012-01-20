#--
# Copyright (c) 2011 Jae Kwon 
#++

config = require 'config'
harmonic = require 'harmonic'

class exports.User extends harmonic.db.Model
  @collection: 'user'
  @index {username: 1}, {unique: true}

  validate: ->
    # e.g. @v.checkField('text').len(3, 1024)
