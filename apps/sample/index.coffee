harmonic = require 'harmonic'

@models = {Page} = require('./models')
@templates = new harmonic.templates.Templar(require, './templates', '../../templates')
@pathPrefix = '/sample'
@routes =
  index:
    path: '', fn: (req, res) ->
      switch req.method
        when 'GET'
          res.render 'index'

  list:
    path: '/list', fn: (req, res) ->
      switch req.method
        when 'GET'
          res.render 'list', args: [[]]

  show:
    path: '/show/:pageId', fn: (req, res) ->
      switch req.method
        when 'GET'
          Page.findOne req.path.pageId, (err, page) ->
            if err?
              console.log err, 'ERR!'
            else
              res.render 'show', args: [page]

  create:
    path: '/create', fn: (req, res, {urlFor}) ->
      switch req.method
        when 'GET'
          res.render 'create'
        when 'POST'
          Page.create req.body.page, (err, page) ->
            if err?
              console.log err, 'ERR!'
            else
              res.redirect urlFor('show', pageId: page.data._id)
