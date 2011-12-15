config = require 'config'
harmonic = require 'harmonic'

class exports.Page extends harmonic.db.Record
  @collection_name: "#{config.mongo.db}.page"

  validate: ->
    # e.g. @v.check_field('text').len(3, 1024)
