#--
# Copyright (c) 2011 Jae Kwon 
#++

config = require 'config'
templates = require './templates'
logger = require('nogg').logger('harmonic.router')
XRegExp = require 'xregexp'
assert = require 'assert'
http = require 'http'
_ = require 'underscore'

do -> # prototype extensions
  _.extend(http.ServerResponse.prototype, {
    simpleJSON: (code, obj) ->
      body = new Buffer(JSON.stringify(obj))
      this.writeHead(code, { 'Content-Type': 'text/json', 'Content-Length': body.length })
      this.end(body)

    redirect: (url) ->
      this.writeHead(302, Location: url)
      this.end()

    reply: (status, headers, data) ->
      this.writeHead (status || 200), (headers || {status: 'ok'})
      this.end data
  })

# A single servlet function. A Router has many Routes.
class exports.Route

  # @routedata:
  #   name:         A globally unique name for the route.
  #   namePrefix:  Prepended to the name.
  #   path:         A regexp type with :capture tokens. See 'pathPrefix' below.
  #   pathPrefix:  Prepended to the path.
  #   reverse:      A function to construct a path from arguments. (optional)
  #   templates:    An instance of Templar.
  #   fn:           The serving function.
  #   wrap:         Decorators for the fn, much like connect middleware.
  #                 Should be 'wrappers' but I chose a four letter word. (optional)
  #   NOTE -- both fn and wrappers get bound to this Route instance.
  constructor: (@router, @routedata) ->
    _.extend(this, @routedata)
    @path = "#{@pathPrefix}#{@path}" if @pathPrefix
    @name = "#{@namePrefix}#{@name}" if @namePrefix
    @xregexp ||= new XRegExp('^'+@path.replace(/:([^\/]+)/g, '(?<$1>[^\/]+)')+'$')

    # construct an array of functions to call in sequence
    # notice that the wrappers
    @chain = if this.wrappers then (wrapper.bind(this) for wrapper in this.wrappers) else []
    @chain.push(this.fn.bind(this))

  serve: (req, res) =>
    this.extendReqRes(req, res)
    chainCounter = 0
    # TODO this could be hard to debug with wrappers incorrectly calling next() multiple times.
    next = (req, res) =>
      nextWrapper = @chain[chainCounter++]
      nextWrapper(req, res, next)
    # and finally
    next(req, res)

  extendReqRes: (req, res) ->
    if @templates?
      # add request-level context values
      res.renderLayout = (template, options, args...) =>
        options ||= {}
        reqContext = {
          reverse: @router.reverse,
          req: req,
          currentUser: req.session?.user
        }
        # caller's context overrides everything
        options.context = _.extend(reqContext, options.context || {})
        res.reply 200, {status: 'ok'}, @templates.renderLayout(template, options, args...)

  toString: =>
    "Route{name:'#{@name}' path:'#{@path}'}"

# Main class. Handles an array of routes.
class exports.Router

  constructor: ->
    @routes = []
    @namedRoutes = {}
    return this

  # Main function that serves the request
  serve: (req, res) =>
    # find matching route
    [route, path] = this.matchRoute(req.url)

    # find 404 route
    if not route?
      [route, path] = this.matchRoute('ERROR/404')

    # no 404 route!
    if not route?
      message = "Couldn't match a route for url #{req.url}, and dunno what to do for a 404 error. Create a route for ERROR/404"
      console.log message
      res.writeHead 404, message
      return false
    req.path = path
    this.forward(req, res, route: route)

  # Forward the request to the route given in options.
  # options:
  #   path:    find a route by path
  #   name:    find a route by name
  #   route:   use this route
  forward: (req, res, options) =>
    if options.path?
      # find matching route
      [route, matched] = this.matchRoute(options.path)
      if not route?
        message = "Couldn't match a forwarded route for path #{options.path}"
        console.log message
        res.writeHead 404, message
        return
    else if options.name?
      message = "Forwarding route by name not implemented yet"
      console.log message
      res.writeHead 404, message
      return
    else if options.route?
      route = options.route
    else
      message = "Forwarding option must be one of path/name/route."
      console.log message
      res.writeHead 404, message
      return

    # finally,
    route.serve(req, res)

  # Find a matching route
  # Path can be a url path starting with /, 
  # or special routes like ERROR/*
  matchRoute: (path) ->
    path = path.split('?', 1)
    for route in @routes
      matched = route.xregexp.exec(path)
      if matched? then return [route, matched]
    return [null, undefined]

  # Reverse a named route
  # Looks for a 'reverse' function,
  # otherwise tries to reverse the regex
  reverse: (name, args) =>
    assert.ok(@namedRoutes[name]?, "Unknown route name #{name}")
    args ||= {}
    if @namedRoutes[name].reverse
      return @namedRoutes[name].reverse(args)
    else
      xregexp = @namedRoutes[name].xregexp
      assert.deepEqual(_.keys(args).sort(), (xregexp._xregexp.captureNames || []).sort(), "capture names don't match")
      reversed = xregexp._xregexp.source
      if reversed[0] == '^' then reversed = reversed[1...]
      if reversed[reversed.length-1] == '$' then reversed = reversed[...reversed.length-1]
      for key, value of args
        reversed = reversed.replace(///\(\?<#{key}>[^)]+\)///, value)
      return reversed

  # A function to append more routes.
  # routesData:
  #   namePrefix:  the keys of routes will be prefixed by "#{routesData.namePrefix}:" (required)
  #   pathPrefix:  if present, paths in routes will be prepended by this (optional)
  #   templates:    if present, res.renderLayout will be set accordingly (optional)
  #   routes:       an object of {routeName: routeObject, ...}
  extendRoutes: (routesData) =>
    assert.ok(routesData.namePrefix?)
    defaultData =
      namePrefix: routesData.namePrefix
      pathPrefix: routesData.pathPrefix
      templates:   routesData.templates
    for name, route of routesData.routes
      routeData = _.extend( _.clone(defaultData), route )
      route = new exports.Route(this, routeData)
      this.addRoute(route)

  # Add a Route object
  addRoute: (route) =>
    if route.name
      assert.equal(@namedRoutes[route.name], undefined, "The route name '#{route.name}' is not unique!")
      @namedRoutes[route.name] = route
    @routes.push(route)
