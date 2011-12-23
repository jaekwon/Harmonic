exports.template = (page) ->
  @text "#{page.data}"
  @ul ->
    @li ->
      @a href: @urlFor('sample:create'), 'create'
