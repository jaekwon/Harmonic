exports.template = ->
  @p "Are you in the zone yet?"

  @ul ->
    @li ->
      if @req.session?.user?
        @a href: '/logout', 'logout'
      else
        @a href: '/login', 'login'
    @li ->
      @a href: '/sample', 'sample app'

exports.coffeescript = ->
  console.log "'tis working!"
