exports.template = (pages) ->
  @ol ->
    for page in pages
      @li ->
        @a href: @reverse('sample:show', id: "#{page.data._id}"), "#{page.data._id}"
  @a href: @reverse('sample:create'), 'create'
