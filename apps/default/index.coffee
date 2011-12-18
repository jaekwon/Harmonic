harmonic = require 'harmonic'

@models = {Page} = require('./models')
@templates = templates = new harmonic.templates.Templar(require, './templates', '../../templates')
@routes =

  index:
    path: '/', fn: (req, res) ->
      switch req.method
        when 'GET'
          res.render_layout('index')

  page:
    path: '/p/:page', fn: (req, res) ->
      switch req.method
        when 'GET'
          res.render_layout("/pages/#{req.path.page}")

  error:
    path: 'ERROR/:code', fn: (req, res) ->
      res.reply Number(req.path.code),
        {status: 'error'}, templates.render_layout("error#{req.path.code}")
