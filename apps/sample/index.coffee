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
          Page.findOne req.path.pageId, (err, page) ->
            if err?
              console.log err, 'ERR!'
            else
              res.renderLayout('show', null, page)

  create:
    path: '/create', fn: (req, res, {urlFor}) ->
      switch req.method
        when 'GET'
          res.renderLayout('create')
        when 'POST'
          Page.create req.body.page, (err, page) ->
            if err?
              console.log err, 'ERR!'
            else
              res.redirect urlFor('show', pageId: page.data._id)
