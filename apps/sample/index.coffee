harmonic = require 'harmonic'

@models = {Page} = require('./models')
@templates = new harmonic.templates.Templar(require, './templates', '../../templates')
@pathPrefix = '/sample'
@routes =

  index:
    path: '', fn: (req, res) ->
      GET: ->
        res.render 'index'

  list:
    path: '/list', fn: (req, res, $) ->
      GET: ->
        Page.find {}, $.try (pages) ->
          res.render 'list', args: [pages]

  show:
    path: '/show/:id', fn: (req, res, $) ->
      GET: ->
        Page.findOne req.path.id, $.try (page) ->
          res.render 'show', args: [page]

  create:
    path: '/create', fn: (req, res, $) ->
      GET: ->
        res.render 'create'
      POST: ->
        Page.create req.body.page, $.try (page) ->
          res.redirect $.urlFor('show', id: page.data._id)
