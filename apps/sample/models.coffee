config = require 'config'
harmonic = require 'harmonic'

class exports.Page extends harmonic.db.Model
  @collection: 'page'

  validate: ->
    # e.g. @v.checkField('text').len(3, 1024)
