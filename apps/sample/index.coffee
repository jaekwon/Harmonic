harmonic = require 'harmonic'
templates = new harmonic.templates.Templar(require, './templates', '../../templates')

Page = require('./models').Page

exports.extend_routes = (router) ->
  router.extend_routes({templates: templates, path_prefix: '/sample'},
    {
      name: 'sample:index'
      path: '', fn: (req, res) ->
        switch req.method
          when 'GET'
            res.render_layout('index')
    },{
      name: 'sample:list'
      path: '/list', fn: (req, res) ->
        switch req.method
          when 'GET'
            res.render_layout('list', null, [])
    },{
      name: 'sample:show'
      path: '/show', fn: (req, res) ->
        switch req.method
          when 'GET'
            res.render_layout('show', null)
    },{
      name: 'sample:create'
      path: '/create', fn: (req, res) ->
        switch req.method
          when 'GET'
            res.render_layout('create')
          when 'POST'
            # TODO
            res.render_layout('create')
    }
  )
