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
  #   name_prefix:  Prepended to the name.
  #   path:         A regexp type with :capture tokens. See 'path_prefix' below.
  #   path_prefix:  Prepended to the path.
  #   reverse:      A function to construct a path from arguments. (optional)
  #   templates:    An instance of Templar.
  #   fn:           The serving function.
  #   wrap:         Decorators for the fn, much like connect middleware.
  #                 Should be 'wrappers' but I chose a four letter word. (optional)
  #   NOTE -- both fn and wrappers get bound to this Route instance.
  constructor: (@router, @routedata) ->
    _.extend(this, @routedata)
    @path = "#{@path_prefix}#{@path}" if @path_prefix
    @name = "#{@name_prefix}#{@name}" if @name_prefix
    @xregexp ||= new XRegExp('^'+@path.replace(/:([^\/]+)/g, '(?<$1>[^\/]+)')+'$')

    # construct an array of functions to call in sequence
    # notice that the wrappers
    @chain = if this.wrappers then (wrapper.bind(this) for wrapper in this.wrappers) else []
    @chain.push(this.fn.bind(this))

  serve: (req, res) =>
    this.extend_req_res(req, res)
    chain_counter = 0
    # TODO this could be hard to debug with wrappers incorrectly calling next() multiple times.
    next = (req, res) =>
      next_wrapper = @chain[chain_counter++]
      next_wrapper(req, res, next)
    # and finally
    next(req, res)

  extend_req_res: (req, res) ->
    if @templates?
      # add request-level context values
      res.render_layout = (template, options, args...) =>
        options ||= {}
        req_context = {
          reverse: @router.reverse,
          req: req,
          current_user: req.session?.user
        }
        # caller's context overrides everything
        options.context = _.extend(req_context, options.context || {})
        res.reply 200, {status: 'ok'}, @templates.render_layout(template, options, args...)

  toString: =>
    "Route{name:'#{@name}' path:'#{@path}'}"

# Main class. Handles an array of routes.
class exports.Router

  constructor: ->
    @routes = []
    @named_routes = {}
    return this

  # Main function that serves the request
  serve: (req, res) =>
    # find matching route
    [route, path] = this.match_route(req.url)

    # find 404 route
    if not route?
      [route, path] = this.match_route('ERROR/404')

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
      [route, matched] = this.match_route(options.path)
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
  match_route: (path) ->
    path = path.split('?', 1)
    for route in @routes
      matched = route.xregexp.exec(path)
      if matched? then return [route, matched]
    return [null, undefined]

  # Reverse a named route
  # Looks for a 'reverse' function,
  # otherwise tries to reverse the regex
  reverse: (name, args) =>
    assert.ok(@named_routes[name]?, "Unknown route name #{name}")
    args ||= {}
    if @named_routes[name].reverse
      return @named_routes[name].reverse(args)
    else
      xregexp = @named_routes[name].xregexp
      assert.deepEqual(_.keys(args).sort(), (xregexp._xregexp.captureNames || []).sort(), "capture names don't match")
      reversed = xregexp._xregexp.source
      if reversed[0] == '^' then reversed = reversed[1...]
      if reversed[reversed.length-1] == '$' then reversed = reversed[...reversed.length-1]
      for key, value of args
        reversed = reversed.replace(///\(\?<#{key}>[^)]+\)///, value)
      return reversed

  # A function to append more routes.
  # routes_data:
  #   name_prefix:  the keys of routes will be prefixed by "#{routes_data.name_prefix}:" (required)
  #   path_prefix:  if present, paths in routes will be prepended by this (optional)
  #   templates:    if present, res.render_layout will be set accordingly (optional)
  #   routes:       an object of {route_name: route_object, ...}
  extend_routes: (routes_data) =>
    assert.ok(routes_data.name_prefix?)
    default_data =
      name_prefix: routes_data.name_prefix
      path_prefix: routes_data.path_prefix
      templates:   routes_data.templates
    for name, route of routes_data.routes
      route_data = _.extend( _.clone(default_data), route )
      route = new exports.Route(this, route_data)
      this.add_route(route)

  # Add a Route object
  add_route: (route) =>
    if route.name
      assert.equal(@named_routes[route.name], undefined, "The route name '#{route.name}' is not unique!")
      @named_routes[route.name] = route
    @routes.push(route)
