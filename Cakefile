{spawn, exec} = require 'child_process'

config = require 'config'
harmonic = require 'harmonic'
_ = require 'underscore'
log = console.log

task 'mongo', ->
  # find all models from apps
  models = []
  for appname, apploc of config.apps
    app = require(apploc)
    models.push(app.models) if app.models?
  # ensure indices for these models
  harmonic.db.mongo.ensure_indices_for models, (err, values) ->
    if err?
      log "ERROR! #{err}"
    else
      log "Done! #{values}"
    harmonic.db.mongo.shutdown()

run = (args...) ->
  for a in args
    switch typeof a
      when 'string' then command = a
      when 'object'
        if a instanceof Array then params = a
        else options = a
      when 'function' then callback = a
  
  command += ' ' + params.join ' ' if params?
  cmd = spawn '/bin/sh', ['-c', command], options
  cmd.stdout.on 'data', (data) -> process.stdout.write data
  cmd.stderr.on 'data', (data) -> process.stderr.write data
  process.on 'SIGHUP', -> cmd.kill()
  cmd.on 'exit', (code) -> callback() if callback? and code is 0
