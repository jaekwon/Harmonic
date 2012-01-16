logger = require('nogg').logger('apps.auth')

module.exports = (options) ->
  return (req, res, next) ->
    if not req.session?
      logger.warn "Auth app requires connect.session."
      return next()
    next()
