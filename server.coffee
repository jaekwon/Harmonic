#--
# Copyright (c) 2011 Jae Kwon 
#++

config = require 'config'
harmonic = require 'harmonic'
templates = new harmonic.Templar(require)
connect = require 'connect'
http = require 'http'
logger = require('nogg').logger('app')

# TODO move to an init script
if config.catch_uncaught_errors
  process.on 'uncaughtException', (err) ->
    logger.error "________________"
    logger.error "http://debuggable.com/posts/node-js-dealing-with-uncaught-exceptions:4c933d54-1428-443c-928d-4e1ecbdd56cb"
    logger.error err.message
    logger.error err.stack
    logger.error "^^^^^^^^^^^^^^^^"

# default routes.
router = new harmonic.Router({templates: templates},
  {
    path: '/', fn: (req, res) ->
      switch req.method
        when 'GET'
          res.render_layout('index')
  },{
    path: '/p/:page', fn: (req, res) ->
      switch req.method
        when 'GET'
          res.render_layout("/pages/#{req.path.page}")
  },{
    path: 'ERROR/404', fn: (req, res) ->
      res.reply 404, {status: 'error'}, templates.render_layout('error404')
  }
)

# add applications
require('apps/auth').extend_routes(router)
require('apps/sample').extend_routes(router)

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
  .use(require('apps/auth/middleware')()) # consider installing middleware via extend_routes, or similar.
                                          # or, keep things as is, because explicit is the philosophy.
  .use(router.serve)
).listen(config.server.port, config.server.host)

logger.info "Server running at http://#{config.server.host}:#{config.server.port}"
