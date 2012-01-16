exports.template = ->
  @div '#contents', ->
    @text "Create a new page."

    # TODO: change this  to use ...
    @form method: 'POST', action: @urlFor('sample:create'), ->
      @label for: 'title', 'title'
      @input '#title', type: 'text', name: 'page[title]'
      @br()
      @label for: 'text', 'text'
      @textarea '#text', name: 'page[text]'
      @br()
      @label for: 'submit', 'submit'
      @input '#submit', type: 'submit', value: 'submit'
