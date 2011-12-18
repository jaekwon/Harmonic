exports.template = ->
  @ul ->
    @li ->
      @a href: @reverse('sample:list'), 'list'
    @li ->
      @a href: @reverse('sample:create'), 'create'
