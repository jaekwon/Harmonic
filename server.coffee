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

# init-script
if config.catchUncaughtErrors
  process.on 'uncaughtException', (err) ->
    logger.error "________________"
    logger.error "http://debuggable.com/posts/node-js-dealing-with-uncaught-exceptions:4c933d54-1428-443c-928d-4e1ecbdd56cb"
    logger.error err.message
    logger.error err.stack
    logger.error "^^^^^^^^^^^^^^^^"

# Create router
router = new harmonic.Router()
middlewares = []

# Add applications
for appname, apploc of config.apps
  app = require apploc
  routesData = _.extend {namePrefix: appname}, app
  router.extendRoutes routesData
  middlewares.push app.middleware if app.middleware?

# Init connect
c = connect()
  .use(connect.logger())
  .use(connect.staticCache())
  .use('/static', connect.static(__dirname + '/static'))
  .use(connect.favicon())
  .use(connect.cookieParser(config.cookieSecret))
  .use(connect.session({ cookie: { maxAge: 1000*60*60*24*30 }}))
  .use(connect.query())
  .use(connect.bodyParser())
# connect app middlewares
c.use(mw) for mw in middlewares
# connect router
c.use(router.serve)

# Init server
http.createServer(c)
  .listen(config.server.port, config.server.host)

logger.info "Server running at http://#{config.server.host}:#{config.server.port}"
