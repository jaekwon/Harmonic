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
    POST: ->
      @res.render 'login'

  signup: path: '/signup', fn:
    GET: ->
      @res.render 'signup'
    POST: ->
      User.create @req.body.user, @try (user) =>
        # TODO log in to session
        console.log "Created user #{user}!"
        @res.redirect @urlFor 'default:index'
