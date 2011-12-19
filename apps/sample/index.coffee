harmonic = require 'harmonic'

@models = {Page} = require('./models')
@templates = new harmonic.templates.Templar(require, './templates', '../../templates')
@pathPrefix = '/sample'
@routes =
  index:
    path: '', fn: (req, res) ->
      switch req.method
        when 'GET'
          res.renderLayout('index')

  list:
    path: '/list', fn: (req, res) ->
      switch req.method
        when 'GET'
          res.renderLayout('list', null, [])

  show:
    path: '/show/:pageId', fn: (req, res) ->
      switch req.method
        when 'GET'
          Page.findOne req.path.pageId
          res.renderLayout('show', null)

  create:
    path: '/create', fn: (req, res) ->
      switch req.method
        when 'GET'
          res.renderLayout('create')
        when 'POST'
          # TODO
          res.renderLayout('create')
