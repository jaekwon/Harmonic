harmonic = require 'harmonic'
assert = require 'assert'

describe 'Router', ->

  router = new harmonic.Router()
  router.extendRoutes
    namePrefix: 'test:'
    routes:
      route1:
        rvrs: -> "path/#{@foo}/#{@bar}"
        path: "path/:foo/:bar", fn: (res, req) ->
          console.log 'dontcare'
      route2:
        path: "path/:foo/:bar", fn: (res, req) ->
          console.log 'dontcare'

  describe '#urlFor', ->
    it 'works with <Route>.rvrs', ->
      assert.equal(
        router.urlFor('test:route1', foo: 'FOO', bar: 'BAR')
        'path/FOO/BAR'
      )

    it 'works without <Route>.rvrs', ->
      assert.equal(
        router.urlFor('test:route2', foo: 'FOO', bar: 'BAR')
        'path/FOO/BAR'
      )
