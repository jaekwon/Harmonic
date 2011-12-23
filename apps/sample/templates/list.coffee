exports.template = (pages) ->
  @ol ->
    for page in pages
      @li ->
        @a href: @urlFor('sample:show', id: "#{page.data._id}"), "#{page.data._id}"
  @a href: @urlFor('sample:create'), 'create'
