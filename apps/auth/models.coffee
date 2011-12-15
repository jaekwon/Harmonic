#--
# Copyright (c) 2011 Jae Kwon 
#++

config = require 'config'
harmonic = require 'harmonic'

class exports.User extends harmonic.db.Record
  @collection_name: "#{config.mongo.db}.user"

  validate: ->
    # e.g. @v.check_field('text').len(3, 1024)
