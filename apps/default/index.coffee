harmonic = require 'harmonic'

@templates = templates = new harmonic.templates.Templar(require, './templates', '../../templates')
@routes =

  index:
    path: '/', fn: (req, res) ->
      switch req.method
        when 'GET'
          res.render 'index'

  page:
    path: '/p/:page', fn: (req, res) ->
      switch req.method
        when 'GET'
          res.render "pages/#{req.path.page}"

  error:
    path: 'ERROR/:code', fn: (req, res) ->
      res.reply Number(req.path.code),
        {status: 'error'}, templates.render("error#{req.path.code}")
