harmonic = require 'harmonic'
config = require 'config'

@templates = templates = new harmonic.templates.Templar(require, './templates', '../../templates')
@routes =

  index: path: '/', fn:
    GET: ->
      @res.render 'index'

  page: path: '/p/:page', fn:
    GET: ->
      @res.render "pages/#{@req.path.page}"

  error: path: 'ERROR/:code', fn: ({message, error}) ->
    @res.render
      template: 'error'
      status:   Number(@req.path.code),
      headers:  {status: 'error', message: message}
      args:     [@req.path.code, message, error if config.debug]
