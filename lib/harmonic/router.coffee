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
  #   path:         A regexp type with :capture tokens. See 'pathPrefix' below.
  #   rvrs:         A function to construct a path from arguments, used for urlFor. (optional)
  #   wrap:         Decorators for the fn, much like connect middleware. (optional)
  #   fn:           The serving function, gets bound to this <Route>.
  # (the following are optional, used in apps)
  #   namePrefix:   Prepended to the name.
  #   pathPrefix:   Prepended to the path.
  #   templates:    An instance of Templar.
  constructor: (@router, @routedata) ->
    _.extend(this, @routedata)
    @wrap = [@wrap] if typeof @wrap == 'function'
    @path = "#{@pathPrefix}#{@path}" if @pathPrefix
    @name = "#{@namePrefix}#{@name}" if @namePrefix
    @xregexp ||= new XRegExp('^'+@path.replace(/:([^\/]+)/g, '(?<$1>[^\/]+)')+'$')

    # create the chain of functions
    @chain = if @wrap then (wrapper.bind(this) for wrapper in @wrap) else []
    @chain.push(this.fn.bind(this))

  serve: (req, res) =>
    this.extendReqRes(req, res)
    chainIndex = 0
    # a wrapper (and <Route>.fn) takes this (actually, nextProxy below) as the third argument.
    next = (req, res) =>
      fn = @chain[chainIndex++]
      # ensure that 'next' only gets called once per chain fn, using a proxy fn.
      nextCalled = false
      nextProxy = (req, res) =>
        if nextCalled
          throw new Error "'next' called more than once for route '#{@name}' in chain #0+#{chainIndex-1}"
        else
          nextCalled = true
        next(req, res)
      # convenience: set some common keys.
      nextProxy.router = @router
      nextProxy.urlFor = @router.urlFor
      # call next fn in chain.
      fn(req, res, nextProxy)
    # start the chain.
    next(req, res)

  extendReqRes: (req, res) ->
    if @templates?
      # add request-level context values
      res.renderLayout = (template, options, args...) =>
        options ||= {}
        reqContext = {
          urlFor: @router.urlFor,
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
  # Looks for a 'rvrs' function,
  # otherwise tries to reverse the regex
  urlFor: (name, kwargs) =>
    assert.ok(@namedRoutes[name]?, "Unknown route name #{name}. Routes: #{_.keys(@namedRoutes)}")
    if @namedRoutes[name].rvrs
      return @namedRoutes[name].rvrs.call(kwargs)
    else
      xregexp = @namedRoutes[name].xregexp
      assert.deepEqual(_.keys(kwargs).sort(), (xregexp._xregexp.captureNames || []).sort(), "capture names don't match")
      reversed = xregexp._xregexp.source
      if reversed[0] == '^' then reversed = reversed[1...]
      if reversed[reversed.length-1] == '$' then reversed = reversed[...reversed.length-1]
      for key, value of kwargs
        reversed = reversed.replace(///\(\?<#{key}>[^)]+\)///, value)
      return reversed

  # A function to append more routes.
  # routesData:
  #   namePrefix:  the keys of routes will be prefixed by "#{routesData.namePrefix}:" (required)
  #   pathPrefix:  if present, paths in routes will be prepended by this (optional)
  #   templates:    if present, res.renderLayout will be set accordingly (optional)
  #   routes:       an object of {routeName: routeObject, ...}
  extendRoutes: (routesData) =>
    assert.ok(routesData.namePrefix?, "Method extendRoutes expected keyword 'namePrefix'")
    assert.ok(routesData.routes?, "Method extendRoutes expected keyword 'routes'")
    defaultData =
      namePrefix: routesData.namePrefix
      pathPrefix: routesData.pathPrefix
      templates:   routesData.templates
    for name, route of routesData.routes
      routeData = _.extend( _.clone(defaultData), route )
      routeData.name = name
      route = new exports.Route(this, routeData)
      this.addRoute(route)

  # Add a Route object
  addRoute: (route) =>
    if route.name
      assert.equal(@namedRoutes[route.name], undefined, "The route name '#{route.name}' is not unique!")
      @namedRoutes[route.name] = route
    @routes.push(route)
