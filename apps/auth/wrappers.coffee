exports.requireLogin = (req, res, next) ->
  if not req.session?.user?
    return @router.forward 'ERROR/404', req, res, message: 'Unauthorized'
  console.log "WTF"
