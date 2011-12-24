logger = require('nogg').logger('apps.auth')

module.exports = (options) ->
  return (req, res, next) ->
    if not req.session?
      logger.warn "auth app cannot function without connect.session."
      return next()
    next()
