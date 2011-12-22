harmonic = require 'harmonic'
assert = require 'assert'

describe 'Router', ->

  router = new harmonic.Router()
  router.extendRoutes
    namePrefix: 'test:'
    routes:
      route1:
        reverse: (_) -> "path/#{_.foo}/#{_.bar}"
        path: "path/:foo/:bar", fn: (res, req) ->
          console.log 'dontcare'
      route2:
        path: "path/:foo/:bar", fn: (res, req) ->
          console.log 'dontcare'

  describe '#reverse', ->
    it 'works with <Route>.reverse', ->
      assert.equal(
        router.reverse('test:route1', foo: 'FOO', bar: 'BAR')
        'path/FOO/BAR'
      )

    it 'works without <Route>.reverse', ->
      assert.equal(
        router.reverse('test:route2', foo: 'FOO', bar: 'BAR')
        'path/FOO/BAR'
      )
