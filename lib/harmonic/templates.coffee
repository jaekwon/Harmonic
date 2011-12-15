#--
# Copyright (c) 2011 Jae Kwon 
#++

config = require 'config'
logger = require('nogg').logger('harmonic.templates')
coffeemugg = require 'coffeemugg'
coffeescript = require 'coffee-script'
_ = require 'underscore'

# a function to add a digest nonce parameter to a static file to help with client cache busting
_static_file_cache = {}
exports.static_file = static_file = (filepath) ->
  if not _static_file_cache[filepath]
    fullfilepath = "static/#{filepath}"
    nonce = require('hashlib').md5(require('fs').statSync(fullfilepath).mtime)[1..10]
    logger.debug "SYNC CALL: static_file, nonce = #{nonce}"
    _static_file_cache[filepath] = "/#{fullfilepath}?v=#{nonce}"
  return _static_file_cache[filepath]

# Main templates rendering class.
# 
# require:
#   This require function will be used to import the template file
# templates_dirs:
#   Specify the order in which Templar should look for files.
#   The directory must be relative to @require.
#
# Layout files will be searched for in the layouts directory.
class exports.Templar

  constructor: (@require, @templates_dirs...) ->
    if @templates_dirs.length == 0
      @templates_dirs = ['./templates']
    @template_mtimes = {}
    @CMContext = coffeemugg.CMContext.extend({
      require: @require
      _render: @render
      #render: gets defined dynamically to pass on options
      static_file: static_file
      site: config.site
    })

  # Filename can be relative.
  template_require: (filename) ->
    # TODO cache
    for templates_dir in @templates_dirs
      try
        path = @require.resolve("#{templates_dir}/#{filename}.coffee")
        break
      catch err
        # pass
    if not path?
      throw new Error("Could not find template '#{filename}' given template_dirs #{@templates_dirs}")

    # Auto-reloading of templates for developement
    if config.debug
      stat = require('fs').statSync(path)
      if not @template_mtimes[path] or @template_mtimes[path] < stat.mtime
        logger.info "loading templates/#{filename}.coffee template..."
        @template_mtimes[path] = stat.mtime
        delete require.cache[path]

    tmpl_module = require(path)
    # validate this module
    # TODO cache
    if not tmpl_module.template?
      throw new Error "The template file #{template} does not export a 'template' coffeemugg function"
    return tmpl_module

  # Main render function.
  #
  # options:
  #   context:  Volatile context values like req, body_template, etc.
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
    tmpl_module = @template_require(template)

    # sass plugin TODO
    # coffeescript plugin
    if tmpl_module.coffeescript and not tmpl_module['_compiled_coffeescript']?
      try
        if typeof tmpl_module.coffeescript == 'function'
          tmpl_module['_compiled_coffeescript'] = "(#{''+tmpl_module.coffeescript})();"
        else
          tmpl_module['_compiled_coffeescript'] = coffeescript.compile(tmpl_module.coffeescript)
      catch err
        logger.error "err in compiling coffeescript for template '#{template}': " + err
        return if config.debug then throw err else undefined
    cm = new @CMContext(format: config.debug, trample_warning: config.debug, context: context)
    
    html = ''
    try
      html += cm.render_contents(tmpl_module.template, args...).toString()
      if tmpl_module._compiled_coffeescript
        html += "\n<script type='text/javascript'>#{tmpl_module._compiled_coffeescript}</script>"
      if tmpl_module._compiled_sass
        html += "\n<style type='text/css'>#{tmpl_module._compiled_sass}</style>"
    catch err
      logger.error "err in rendering template '#{template}': " + err
      return if config.debug then throw err else undefined
    return html

  # Provides a simple means of template layouts.
  #
  # template:   The template to render, not the layout.
  # options:
  #   context:  Volatile context values like req, body_template, etc.
  #             (more static context should be passed in during Templar initialization)
  #             NOTE context.context circular reference will be added.
  #   layout:   The layout to use, default 'layouts/default'
  # args:       Args to pass to above template
  render_layout: (template, options, args...) =>
    layout = options?.layout || 'layouts/default'

    # this will be the actual context for the layout
    # as well as the template
    layout_context = {
      args: args
      layout: layout
      template: template
    }

    # caller's context overrides everything
    _.extend(layout_context, options.context) if options?.context?

    @render(layout, {context: layout_context}, args...)
