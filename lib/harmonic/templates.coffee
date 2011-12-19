#--
# Copyright (c) 2011 Jae Kwon 
#++

config = require 'config'
logger = require('nogg').logger('harmonic.templates')
coffeemugg = require 'coffeemugg'
coffeescript = require 'coffee-script'
_ = require 'underscore'

# a function to add a digest nonce parameter to a static file to help with client cache busting
_staticFileCache = {}
exports.staticFile = staticFile = (filepath) ->
  if not _staticFileCache[filepath]
    fullfilepath = "static/#{filepath}"
    nonce = require('hashlib').md5(require('fs').statSync(fullfilepath).mtime)[1..10]
    logger.debug "SYNC CALL: staticFile, nonce = #{nonce}"
    _staticFileCache[filepath] = "/#{fullfilepath}?v=#{nonce}"
  return _staticFileCache[filepath]

# Main templates rendering class.
# 
# require:
#   This require function will be used to import the template file
# templatesDirs:
#   Specify the order in which Templar should look for files.
#   The directory must be relative to @require.
#
# Layout files will be searched for in the layouts directory.
class exports.Templar

  constructor: (@require, @templatesDirs...) ->
    if @templatesDirs.length == 0
      @templatesDirs = ['./templates']
    @templateMtimes = {}
    @CMContext = coffeemugg.CMContext.extend({
      require: @require
      _render: @render
      #render: gets defined dynamically to pass on options
      staticFile: staticFile
      site: config.site
    })

  # Filename can be relative.
  templateRequire: (filename) ->
    # TODO cache
    for templatesDir in @templatesDirs
      try
        path = @require.resolve("#{templatesDir}/#{filename}.coffee")
        break
      catch err
        # pass
    if not path?
      throw new Error("Could not find template '#{filename}' given templateDirs #{@templatesDirs}")

    # Auto-reloading of templates for developement
    if config.debug
      stat = require('fs').statSync(path)
      if not @templateMtimes[path] or @templateMtimes[path] < stat.mtime
        logger.info "loading templates/#{filename}.coffee template..."
        @templateMtimes[path] = stat.mtime
        delete require.cache[path]

    tmplModule = require(path)
    # validate this module
    # TODO cache
    if not tmplModule.template?
      throw new Error "The template file #{template} does not export a 'template' coffeemugg function"
    return tmplModule

  # Main render function.
  #
  # options:
  #   context:  Volatile context values like req, bodyTemplate, etc.
  #             (more static context should be passed in during Templar initialization)
  #             NOTE context.context circular reference will be added.
  # template: The template function
  render: (template, options, args...) =>
    context = options?.context || {}

    # add circular reference
    context.context = context
    # add @render, which carries the original option values as defaults.
    # NOTE: @_render refers to the original function.
    # NOTE: if you pass in options_.context, it will replace, not merge.
    context.render = (template_, options_, args_...) =>
      if not options_?
        options_ = options
      else
        options_ = _.extend(_.clone(options), options_)
      @render(template_, options_, args_...)

    # get template
    tmplModule = @templateRequire(template)

    # sass plugin TODO
    # coffeescript plugin
    if tmplModule.coffeescript and not tmplModule['_compiledCoffeescript']?
      try
        if typeof tmplModule.coffeescript == 'function'
          tmplModule['_compiledCoffeescript'] = "(#{''+tmplModule.coffeescript})();"
        else
          tmplModule['_compiledCoffeescript'] = coffeescript.compile(tmplModule.coffeescript)
      catch err
        logger.error "err in compiling coffeescript for template '#{template}': " + err
        return if config.debug then throw err else undefined
    cm = new @CMContext(format: config.debug, trampleWarning: config.debug, context: context)
    
    html = ''
    try
      html += cm.render_contents(tmplModule.template, args...).toString()
      if tmplModule._compiledCoffeescript
        html += "\n<script type='text/javascript'>#{tmplModule._compiledCoffeescript}</script>"
      if tmplModule._compiledSass
        html += "\n<style type='text/css'>#{tmplModule._compiledSass}</style>"
    catch err
      logger.error "err in rendering template '#{template}': " + err
      return if config.debug then throw err else undefined
    return html

  # Provides a simple means of template layouts.
  #
  # template:   The template to render, not the layout.
  # options:
  #   context:  Volatile context values like req, bodyTemplate, etc.
  #             (more static context should be passed in during Templar initialization)
  #             NOTE context.context circular reference will be added.
  #   layout:   The layout to use, default 'layouts/default'
  # args:       Args to pass to above template
  renderLayout: (template, options, args...) =>
    layout = options?.layout || 'layouts/default'

    # this will be the actual context for the layout
    # as well as the template
    layoutContext = {
      args: args
      layout: layout
      template: template
    }

    # caller's context overrides everything
    _.extend(layoutContext, options.context) if options?.context?

    @render(layout, {context: layoutContext}, args...)
