#--
# Copyright (c) 2011 Jae Kwon 
#++

{Templar} = require 'harmonic'

@middleware = (req, res, next) ->
  req.user = new User(req.session.user) if req.session.user?
  next()
@models = {User} = require './models'
@templates = new Templar(require, './templates', '../../templates')
@routes =

  signup: path: '/signup', fn:
    GET: ->
      @res.render 'signup'
    POST: ->
      User.create @req.body.user, @try (user) =>
        @req.session.user = user.data
        @req.session.loginDate = new Date()
        @res.redirect @urlFor 'default:index'

  login: path: '/login', fn:
    GET: ->
      @res.render 'login'
    POST: ->
      @res.render 'login'

  logout: path: '/logout', fn: ->
    delete @req.session.user
    @res.redirect @urlFor 'default:index'
