#--
# Copyright (c) 2011 Jae Kwon 
#++

config = require 'config'
templates = require './templates'
logger = require('nogg').logger('harmonic.router')
XRegExp = require 'xregexp'
assert = require 'assert'
http = require 'http'
{Fn} = require 'cardamom'
_ = require 'underscore'

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
  # - kwargs:   Forward-level request keyword arguments.
  # Returns true if forwarding succeeded, false 
  # NOTE: kwargs may get modified, say, by a wrapper function
  forward: (path, req, res, kwargs={}) =>

    # Iterate over @routes and look for a path match.
    for route in @routes
      matched = route.xregexp.exec(path)
      if matched
        req.path = matched
        route.serve(req, res, kwargs)
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
      expectedNames = (xregexp._xregexp.captureNames || []).sort()
      kwargNames = _.keys(kwargs).sort()
      assert.deepEqual(kwargNames, expectedNames, "Path capture names don't match for route. Expected: [#{expectedNames.join ','}], got: [#{kwargNames.join ','}]")
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
  #   - fn:           The serving function, gets bound to this <Route>. Or an object of {METHOD: fn}
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

    # support fn as {method: fn}
    if typeof @fn is 'object'
      methodFns = @fn
      @fn = ->
        targetFn = methodFns[@req.method]
        if not targetFn
          return @router.forward('ERROR/405', @req, @res, message: "Method #{req.method} not allowed")
        return targetFn.apply(this, arguments)

    # create the chain of functions
    @chain = _.clone @wrap or []
    @chain.push @fn

  # Service the req to res for this <Route>.
  # Keys bound to this (@):
  #   - req
  #   - res
  #   - forward:  (path, kwargs)-> ...
  #   - error:    (code, kwargs)-> ...
  #   - urlFor:   (name, kwargs)->"url"
  #   - router:   <Router>
  #   - route:    <Route>
  #   - try:      Decorator to forward to ERROR/500 upon errors.
  # e.g.
  #   @routes = 
  #     route1: path: 'PATH1', fn: ->
  #         @router.forward 'PATH2', req, res, {foo: 'FOO', bar: 'BAR'}
  #     route2: path: 'PATH2', fn: ({foo, bar}) ->
  #         @res.render 'myTemplate', foo, bar
  #     ...
  # NOTE: kwargs may get modified, say, by a wrapper function
  serve: (req, res, kwargs={}) =>
    @_extendReqRes(req, res)
    keys = @_getKeys(req, res)

    # Construct a portal function 'next' through the wrapper chain.
    chainIndex = 0
    next = () =>
      fn = @chain[chainIndex++]
      if chainIndex < @chain.length
        # ensure that 'next' only gets called once per chain fn, using a proxy fn.
        nextCalled = false
        nextProxy = (req, res) =>
          if nextCalled
            throw new Error "'next' called more than once for route '#{@name}' in chain #0+#{chainIndex-1}"
          else
            nextCalled = true
          next()
        # call next wrapper fn in chain
        fn.call(keys, kwargs, nextProxy)
      else
        # call the fn
        fn.call(keys, kwargs)

    # start the chain.
    next(req, res)

  # Just like <Router>.urlFor, except @namePrefix
  # gets prepended if need be.
  urlFor: (name, kwargs) =>
    if ':' not in name
      name = "#{@namePrefix}:#{name}"
    @router.urlFor(name, kwargs)

  _extendReqRes: (req, res) ->
    if @templates?
      res.render = Fn '["template"?] {options}? args...', (template, options={}, args...) =>
        options.layout ?= 'layouts/default'
        options.context ||= {}
        _.defaults options.context, {
          req: req
          urlFor: @urlFor
        }
        status = options.status ? 200
        headers = options.headers ? {status: 'ok'}
        res.reply status, headers, @templates.render(template, options, args...)

  _getKeys: (req, res) ->
    keys =
      req:      req
      res:      res
      route:    this
      router:   @router
      urlFor:   @urlFor
      error:    (code, kwargs) => @router.forward('ERROR/'+code, req, res, kwargs)
      forward:  (path, kwargs) => @router.forward(path, req, res, kwargs)
      try:      (fn) =>
                  (err, args...) =>
                    if err?
                      @router.forward('ERROR/500', req, res, error: err, message: 'Internal Error!')
                    else
                      fn(args...)
    keys

  toString: =>
    "Route{name:'#{@name}' path:'#{@path}'}"

# Prototype extensions
_.extend(http.ServerResponse.prototype, {
  simpleJSON: (code, obj) ->
    body = new Buffer(JSON.stringify(obj))
    this.writeHead(code, { 'Content-Type': 'text/json', 'Content-Length': body.length })
    this.end(body)

  redirect: (url) ->
    this.writeHead(302, Location: url)
    this.end()

  reply: (status, headers, data) ->
    this.writeHead (status ? 200), (headers ? {status: 'ok'})
    this.end data
})
