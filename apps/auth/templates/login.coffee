exports.template = ->
  @h2 "Log in"

  @form method: 'POST', action: @urlFor('auth:login'), ->
    @label for: 'username', 'username'
    @input type: 'text', name: 'username'
    @br()
    @label for: 'password', 'password'
    @textarea name: 'password'
    @br()
    @input type: 'submit', value: 'submit'

  @a href: @urlFor('auth:signup'), 'Sign up'
