{Templar} = require 'harmonic'

@models = {Page} = require('./models')
@templates = new Templar(require, './templates', '../../templates')
@pathPrefix = '/sample'
@routes =

  index: path: '', fn:
    GET: ->
      @res.render 'index'

  list: path: '/list', fn:
    GET: ->
      Page.find {}, @try (pages) =>
        @res.render 'list', args: [pages]

  show: path: '/show/:id', fn:
    GET: ->
      Page.findOne @req.path.id, @try (page) =>
        @res.render 'show', args: [page]

  create: path: '/create', fn:
    GET: ->
      @res.render 'create'
    POST: ->
      Page.create @req.body.page, @try (page) =>
        @res.redirect @urlFor 'show', id: page.data._id
