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
if config.catch_uncaught_errors
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
    routes_data = {name_prefix: appname+":"}
    _.extend(routes_data, require(apploc))
    router.extend_routes(routes_data)

# init server
http.createServer(connect()
  .use(connect.logger())
  .use(connect.staticCache())
  .use('/static', connect.static(__dirname + '/static'))
  .use(connect.favicon())
  .use(connect.cookieParser(config.cookie_secret))
  .use(connect.session({ cookie: { maxAge: 1000*60*60*24*30 }}))
  .use(connect.query())
  .use(connect.bodyParser())
  .use(require('apps/auth/middleware')()) # TODO consider auto-installation of middleware
  .use(router.serve)
).listen(config.server.port, config.server.host)

logger.info "Server running at http://#{config.server.host}:#{config.server.port}"
