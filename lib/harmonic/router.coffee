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

# Main class.
# Handles an array of <Route> instances.
class exports.Router

  constructor: ->
    @routes = []
    @namedRoutes = {}
    this

  # Main function that serves the request.
  # Pass it into httpServer.
  serve: (req, res) =>
    {path} = require('url').parse(req.url)
    @forward(path, req, res)

  # Forward the request to the route given by the path.
  # - path:     The path to forward to.
  # - keys:     Forward-level request keyword arguments.
  #             The following keys are provided for convenience and are reserved.
  #               - forward:  (path, keys)->...
  #               - urlFor:   (name, kwargs)->"url"
  #               - router:   <Router>
  #               - self:     <Route>
  #               - Try:      Decorator to forward to ERROR/500 upon errors.
  #             e.g.
  #               @routes = 
  #                 route1:
  #                   path: 'PATH1', fn (req, res) ->
  #                     @router.forward 'PATH2', req, res, {foo: 'FOO', bar: 'BAR'}
  #                 route2:
  #                   path: 'PATH2', fn (req, res, {foo, bar, forward}) ->
  #                     forward 'PATH3', {baz: 'BAZ'}
  #                 ...
  # Returns true if forwarding succeeded, false 
  forward: (path, req, res, keys) =>

    # Iterate over @routes and look for a path match.
    for route in @routes
      matched = route.xregexp.exec(path)
      if matched
        req.path = matched
        route.serve(req, res, keys)
        return true

    # Couldn't find a route matching the path.
    if path == 'ERROR/404'
      message = "Couldn't match a route for url #{req.url}, and dunno what to do for a 404 error. Create a route for ERROR/404"
      res.writeHead 404, message
      return false
    else
      return @forward 'ERROR/404', req, res, message: "Couldn't find a route matching path: '#{path}'"

  # Reverse a named route
  # Looks for a 'rvrs' function,
  # otherwise tries to reverse the regex
  urlFor: (name, kwargs={}) =>

    # validation
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

    # validation
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

  # Service the req to res for this <Route>.
  # - keys:     Forward-level request keyword arguments. See Router.forward.
  serve: (req, res, keys) =>
    @_extendReqRes(req, res)
    keys = @_extendKeys(req, res, keys)

    # Construct a portal function 'next' through the wrapper chain.
    chainIndex = 0
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
      # HACK to provide the keys in the third argument.
      # API may change in the future.
      _.extend nextProxy, keys
      nextProxy.next = nextProxy
      # call next fn in chain.
      result = fn(req, res, nextProxy)
      # method-switch convenience.
      if @_isMethodSwitch(result)
        if not result[req.method]
          return @router.forward('ERROR/405', req, res, message: "Method #{req.method} not allowed")
        result[req.method](req, res, nextProxy)

    # start the chain.
    next(req, res)

  # Just like <Router>.urlFor, except @namePrefix
  # gets prepended if need be.
  urlFor: (name, kwargs) =>
    if ':' not in name
      name = "#{@namePrefix}:#{name}"
    @router.urlFor(name, kwargs)

  _isMethodSwitch: (result) ->
    (typeof result) == 'object' and _.intersection(_.keys(result), ['GET', 'POST', 'PUT', 'DELETE', 'HEAD']).length > 0

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

  _extendKeys: (req, res, moreKeys) ->
    keys =
      router:   @router
      urlFor:   @urlFor
      forward:  (path, keys) => @router.forward(path, req, res, keys)
      self:     this
      # TODO refactor out, unify with the default way of handling errors in connect.
      Try:      (fn) =>
                  (err, args...) =>
                    if err?
                      @router.forward('ERROR/500', req, res, error: err, message: 'Internal Error!')
                    else
                      fn(args...)
    # extend with moreKeys and check for duplicate keys.
    for key, value of moreKeys
      if keys[key]?
        throw new Error "The key '#{key}' is reserved for Routes"
      keys[key] = value
    return keys

  toString: =>
    "Route{name:'#{@name}' path:'#{@path}'}"
