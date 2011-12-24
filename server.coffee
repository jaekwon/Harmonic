#--
# Copyright (c) 2011 Jae Kwon 
#++

config = require 'config'
harmonic = require 'harmonic'
templates = new harmonic.Templar(require)
connect = require 'connect'
http = require 'http'
logger = require('nogg').logger('app')
_ = require 'underscore'

# TODO move to an init script
if config.catchUncaughtErrors
  process.on 'uncaughtException', (err) ->
    logger.error "________________"
    logger.error "http://debuggable.com/posts/node-js-dealing-with-uncaught-exceptions:4c933d54-1428-443c-928d-4e1ecbdd56cb"
    logger.error err.message
    logger.error err.stack
    logger.error "^^^^^^^^^^^^^^^^"

# create router
router = new harmonic.Router()

# add applications
for appname, apploc of config.apps
  do (appname, apploc) ->
    app = require(apploc)
    routesData = {namePrefix: appname}
    _.extend(routesData, require(apploc))
    router.extendRoutes(routesData)

# Debug middleware
logErrors = (options) ->
  return (req, res, next) ->
    try
      next()
    catch err
      console.log "ERRORS: #{err}"
    finally
      console.log 'NO ERRORS'

# init server
http.createServer(connect()
  .use(logErrors())
  .use(connect.logger())
  .use(connect.staticCache())
  .use('/static', connect.static(__dirname + '/static'))
  .use(connect.favicon())
  .use(connect.cookieParser(config.cookieSecret))
  .use(connect.session({ cookie: { maxAge: 1000*60*60*24*30 }}))
  .use(connect.query())
  .use(connect.bodyParser())
  .use(require('apps/auth/middleware')()) # TODO consider auto-installation of middleware
  .use(router.serve)
).listen(config.server.port, config.server.host)

logger.info "Server running at http://#{config.server.host}:#{config.server.port}"
