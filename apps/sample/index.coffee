harmonic = require 'harmonic'

@models = {Page} = require('./models')
@templates = new harmonic.templates.Templar(require, './templates', '../../templates')
@path_prefix = '/sample'
@routes =
  index:
    path: '', fn: (req, res) ->
      switch req.method
        when 'GET'
          res.render_layout('index')

  list:
    path: '/list', fn: (req, res) ->
      switch req.method
        when 'GET'
          res.render_layout('list', null, [])

  show:
    path: '/show/:page_id', fn: (req, res) ->
      switch req.method
        when 'GET'
          Page.findOne req.path.page_id
          res.render_layout('show', null)

  create:
    path: '/create', fn: (req, res) ->
      switch req.method
        when 'GET'
          res.render_layout('create')
        when 'POST'
          # TODO
          res.render_layout('create')
