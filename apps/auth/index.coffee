#--
# Copyright (c) 2011 Jae Kwon 
#++

harmonic = require 'harmonic'

@models = {User} = require './models'
@templates = new harmonic.templates.Templar(require, './templates', '../../templates')
@routes =

  login:
    path: '/login', fn: (req, res) ->
      switch req.method
        when 'GET'
          res.render_layout('login')
        when 'POST'
          res.render_layout('login')
