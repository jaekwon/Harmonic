harmonic = require 'harmonic'

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
    path: 'ERROR/:code', fn: (req, res, {message}) ->
      res.reply Number(req.path.code),
        {status: 'error', message: message},
        templates.render('error', args: [req.path.code, message])
