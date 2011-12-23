exports.template = ->
  @ul ->
    @li ->
      @a href: @urlFor('sample:list'), 'list'
    @li ->
      @a href: @urlFor('sample:create'), 'create'
