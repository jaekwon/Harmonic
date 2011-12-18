exports.template = (page) ->
  @text "#{page.data}"
  @ul ->
    @li ->
      @a href: @reverse('sample:create'), 'create'
