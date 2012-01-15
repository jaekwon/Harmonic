_ = require 'underscore'

exports.template = (page) ->
  @div '#page', ->
    @h1 '#title', page.data.title
    @pre '#text', page.data.text
  @ul ->
    @li ->
      @a href: @urlFor('sample:create'), 'create another'
