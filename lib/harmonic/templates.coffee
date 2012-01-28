#--
# Copyright (c) 2011 Jae Kwon 
#++

config = require 'config'
logger = require('nogg').logger('harmonic.templates')
coffeemugg = require 'coffeemugg'
coffeescript = require 'coffee-script'
assert = require 'assert'
{B, Fn} = require 'cardamom'
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
# - require:      The `require` function will be used to import the template file
# - directories:  Order in which Templar should look for files.
class exports.Templar

  constructor: (@require, @directories...) ->
    if @directories.length == 0
      @directories = ['./templates']
    @templateMtimes = {}
    @CMContext = coffeemugg.CMContext.extend({
      require: @require
      partial: @render # TODO refactor to pass and merge @context through.
      staticFile: staticFile
      site: config.site
    })

  # Main render function.
  # - template:   The template file name.
  # - options:
  #   - template: Another way to pass in the template.
  #   - layout:   (default null)
  #   - context:  Volatile context values like req, bodyTemplate, etc.
  #               NOTE: more static context should be passed in during Templar initialization.
  #   - args:     Arguments to the template function.
  # - args...:    Another way to pass in arguments. (optional)
  render:B Fn '["template"?] {options}? args...', (template, options, args...) ->
    assert.ok not (options?.args? and args.length > 0), "In render, options.args and args... should be exclusive, but both were given"
    layout   = options?.layout
    context  = options?.context  || {}
    args     = options?.args     || args
    template ||= options?.template

    # either fetch the layout or the template.
    baseTemplate = layout || template
    tmplModule = @_templateRequire(baseTemplate)

    # special context vars...
    context.template = template
    context.context  = context

    # TODO generic plugin system for templates.
    # SASS PLUGIN:
    # COFFEESCRIPT PLUGIN:
    if tmplModule.coffeescript and not tmplModule['_compiledCoffeescript']?
      try
        if typeof tmplModule.coffeescript == 'function'
          tmplModule['_compiledCoffeescript'] = "(#{''+tmplModule.coffeescript})();"
        else
          tmplModule['_compiledCoffeescript'] = coffeescript.compile(tmplModule.coffeescript)
      catch err
        logger.error "err in compiling coffeescript for template '#{baseTemplate}': " + err
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
      logger.error "err in rendering template '#{baseTemplate}': " + err
      return if config.debug then throw err else undefined

    return html

  # Returns the module
  # - filename:   Relative file path, without the .coffee extension.
  _templateRequire: (filename) ->
    # TODO cache
    for templatesDir in @directories
      try
        path = @require.resolve("#{templatesDir}/#{filename}.coffee")
        break
      catch err
        # pass
    if not path?
      throw new Error("Could not find template '#{filename}' given templateDirs #{@directories}")

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

  B.ind @
