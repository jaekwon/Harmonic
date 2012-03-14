#--
# Copyright (c) 2011 Jae Kwon 
#++

config = require 'config'
harmonic = require 'harmonic'
{clazz, Fn} = require 'cardamom'

@User = clazz 'User', harmonic.db.Model, ->
  @collection = 'user'
  @index {username: 1}, {unique: true}
  @schema =
    username:   type: 'string', required: yes, length: [2, 15]
    email:      type: 'string', required: yes

  save$: Fn '[{options}?] [cb->]', (options, cb) ->
    @validate self, (err) ->
      return cb(err) if err?
      @super.save(options, cb)
