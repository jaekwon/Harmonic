exports.requireLogin = (req, res, next) ->
  if not req.session?.user?
    return @error 404, message: 'Unauthorized'
  console.log "WTF"
