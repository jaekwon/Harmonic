exports.requireLogin = (req, res, next) ->
  if not req.session?.user?
    @router.forward req, res, path: 'ERROR/404'
    return
  console.log "WTF"
