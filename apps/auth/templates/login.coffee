exports.template = ->
  @text "Login In"

  @form method: 'POST', action: @urlFor('auth:login'), ->
    @label for: 'username', 'username'
    @input type: 'text', name: 'username'
    @br()
    @label for: 'password', 'password'
    @textarea name: 'password'
    @br()
    @label for: 'submit', 'submit'
    @input type: 'submit', value: 'submit'
