#--
# Copyright (c) 2011 Jae Kwon 
#++

{Templar} = require 'harmonic'

@models = {User} = require './models'
@templates = new Templar(require, './templates', '../../templates')
@routes =

  login: path: '/login', fn:
    GET: ->
      @res.render 'login'
