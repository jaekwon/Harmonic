config = require 'config'
harmonic = require 'harmonic'

class exports.Page extends harmonic.db.Record
  @collection: 'page'

  validate: ->
    # e.g. @v.check_field('text').len(3, 1024)
