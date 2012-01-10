harmonic = require 'harmonic'
config = require 'config'

@templates = templates = new harmonic.templates.Templar(require, './templates', '../../templates')
@routes =

  index:
    path: '/', fn: (req, res) ->
      GET: ->
        res.render 'index'

  page:
    path: '/p/:page', fn: (req, res) ->
      GET: ->
        res.render "pages/#{req.path.page}"

  error:
    path: 'ERROR/:code', fn: (req, res, $) ->
      res.render
        template: 'error'
        status:   Number(req.path.code),
        headers:  {status: 'error', message: $.message}
        args:     [req.path.code, $.message, $.error if config.debug]
