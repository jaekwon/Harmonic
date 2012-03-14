config = require 'config'
harmonic = require 'harmonic'
{clazz} = require 'cardamom'

@Page = clazz 'Page', harmonic.db.Model, ->
  @collection = 'page'

  validate: ->
    # e.g. @v.checkField('text').len(3, 1024)
