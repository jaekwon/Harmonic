exports.template = ->
  @div '#contents', ->
    @text "Create a new page."

    # TODO: change this  to use ...
    @form method: 'POST', action: @urlFor('sample:create'), ->
      @label for: 'title', 'title'
      @input id: 'title', type: 'text', name: 'page[title]'
      @br()
      @label for: 'text', 'text'
      @textarea id: 'text', name: 'page[text]'
      @br()
      @label for: 'submit', 'submit'
      @input id: 'submit', type: 'submit', value: 'submit'
