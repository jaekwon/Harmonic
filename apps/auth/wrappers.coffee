@requireLogin = (kwargs, next) ->
  if not @req.user?
    return @error 404, message: 'Unauthorized'
  return next()
