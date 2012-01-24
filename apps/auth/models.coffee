#--
# Copyright (c) 2011 Jae Kwon 
#++

config = require 'config'
harmonic = require 'harmonic'

class exports.User extends harmonic.db.Model
  @collection: 'user'
  @index {username: 1}, {unique: true}

  validate: ->
    @v.checkField('text').len(100,102)

  @on 'beforeCreate', (user, options) ->
    user.validate()
    throw new harmonic.db.ValidationError user.errors if user.errors
