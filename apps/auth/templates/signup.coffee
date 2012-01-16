exports.template = ->
  @h2 "Sign up"

  @form method: 'POST', action: @urlFor('auth:signup'), ->
    @label for: 'username', 'username'
    @input '#username', type: 'text', name: 'user[username]'
    @br()
    @label for: 'password', 'password'
    @input '#password', type: 'text', name: 'user[password]'
    @br()
    @label for: 'password2', 'password repeat'
    @input '#password2', type: 'text', name: 'user[password2]'
    @br()
    @input '#submit', type: 'submit', value: 'submit'

  @text 'Already have an account?'
  @a href: @urlFor('auth:login'), 'Log in'
