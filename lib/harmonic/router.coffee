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

  # - routedata:
  #   - name:         A globally unique name for the route.
  #   - path:         A regexp type with :capture tokens. See 'pathPrefix' below.
  #   - rvrs:         A function to construct a path from arguments, used for urlFor. (optional)
  #   - wrap:         Decorators for the fn, much like connect middleware. (optional)
  #   - fn:           The serving function, gets bound to this <Route>.
  # (the following are optional, used in apps)
  #   - namePrefix:   Prepended to the name.
  #   - pathPrefix:   Prepended to the path.
  #   - templates:    An instance of Templar.
  constructor: (@router, @routedata) ->
    _.extend(this, @routedata)
    @wrap = [@wrap] if typeof @wrap == 'function'
    @path = "#{@pathPrefix}#{@path}" if @pathPrefix
    @name = "#{@namePrefix}:#{@name}" if @namePrefix
    @xregexp ||= new XRegExp('^'+@path.replace(/:([^\/]+)/g, '(?<$1>[^\/]+)')+'$')

    # create the chain of functions
    @chain = if @wrap then (wrapper.bind(this) for wrapper in @wrap) else []
    @chain.push(@fn.bind(this))

  serve: (req, res, data) =>
    @_extendReqRes(req, res)
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
      # convenience: set some common keys, and `data`.
      nextProxy.router = @router
      nextProxy.urlFor = @urlFor
      _.extend nextProxy, data
      # call next fn in chain.
      result = fn(req, res, nextProxy)
      if @_isMethodSwitch(result)
        if not result[req.method]
          return @router.forward('ERROR/405', req, res, message: "Method #{req.method} not allowed")
        result[req.method](req, res, nextProxy)
    # start the chain.
    next(req, res)

  # For convenience, <Route>.fn can return an object like
  #  {GET:, POST:, ...} instead of switching on req.method.
  _isMethodSwitch: (result) ->
    (typeof result) == 'object' and _.intersection(_.keys(result), ['GET', 'POST', 'PUT', 'DELETE', 'HEAD']).length > 0

  # Just like <Router>.urlFor, except @namePrefix
  # gets prepended if need be.
  urlFor: (name, kwargs) =>
    if ':' not in name
      name = "#{@namePrefix}:#{name}"
    @router.urlFor(name, kwargs)

  _extendReqRes: (req, res) ->
    if @templates?
      res.render = (template, options={}, args...) =>
        options.layout ?= 'layouts/default'
        options.context ||= {}
        _.defaults options.context, {
          req: req
          urlFor: @urlFor
          currentUser: req.session?.user
        }
        res.reply 200, {status: 'ok'}, @templates.render(template, options, args...)

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
    {path} = require('url').parse(req.url)
    @forward(path, req, res)

  # Forward the request to the route given in options.
  # - path:     The path to forward to.
  # - data:     Additional data to pass to the route. (optional)
  #             e.g.
  #               @routes = 
  #                 route1:
  #                   path: 'PATH1', fn (req, res) ->
  #                     @router.forward 'PATH2', foo: 'FOO', bar: 'BAR'
  #                 route2:
  #                   path: 'PATH2', fn (req, res, {foo, bar, urlFor}) ->
  #                     ...
  # Returns true if forwarding succeeded, false 
  forward: (path, req, res, data) =>

    # Iterate over @routes and look for a path match.
    for route in @routes
      matched = route.xregexp.exec(path)
      if matched
        route.serve(req, res, data)
        return true

    # Couldn't find a route matching the path.
    if path == 'ERROR/404'
      message = "Couldn't match a route for url #{req.url}, and dunno what to do for a 404 error. Create a route for ERROR/404"
      res.writeHead 404, message
      return false
    else
      return @forward 'ERROR/404', req, res, message: "Couldn't find a route matching path: '#{path}'"

    throw new Error, 'should not happen'

  # Reverse a named route
  # Looks for a 'rvrs' function,
  # otherwise tries to reverse the regex
  urlFor: (name, kwargs={}) =>
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
        assert.ok(value, "Value of urlFor kwarg cannot be null or undefined. key: '#{key}' value: '#{value}'")
        reversed = reversed.replace(///\(\?<#{key}>[^)]+\)///, value)
      return reversed

  # A function to append more routes.
  # - routesData:
  #   - namePrefix:   The keys of routes will be prefixed by "#{routesData.namePrefix}:" (required)
  #   - pathPrefix:   If present, paths in routes will be prepended by this (optional)
  #   - templates:    If present, res.render will be provided (optional)
  #   - routes:       An object of {routeName: routeObject, ...}
  extendRoutes: (routesData) =>
    assert.ok(routesData.namePrefix?, "Method extendRoutes expected keyword 'namePrefix'")
    assert.ok(':' not in routesData.namePrefix, "namePrefix need not include the colon, it gets added automatically.")
    assert.ok(routesData.routes?, "Method extendRoutes expected keyword 'routes'")
    defaultData =
      namePrefix: routesData.namePrefix
      pathPrefix: routesData.pathPrefix
      templates:  routesData.templates
    for name, route of routesData.routes
      routeData = _.defaults _.clone(route), defaultData
      routeData.name = name
      route = new exports.Route(this, routeData)
      @addRoute(route)

  addRoute: (route) =>
    if route.name
      assert.equal(@namedRoutes[route.name], undefined, "The route name '#{route.name}' is not unique!")
      @namedRoutes[route.name] = route
    @routes.push(route)
