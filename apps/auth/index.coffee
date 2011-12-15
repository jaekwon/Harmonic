#--
# Copyright (c) 2011 Jae Kwon 
#++

harmonic = require 'harmonic'
templates = new harmonic.templates.Templar(require, './templates', '../../templates')

User = require('./models').User

exports.extend_routes = (router) ->
  router.extend_routes(templates: templates,
    {
      name: 'auth:login'
      path: '/login', fn: (req, res) ->
        switch req.method
          when 'GET'
            res.render_layout('login')
          when 'POST'
            res.render_layout('login')
    }
  )
