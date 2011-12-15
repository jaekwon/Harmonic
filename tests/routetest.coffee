harmonic = require 'harmonic'

exports.testReverse = (test) ->

  defaults = {}
  router = new harmonic.Router(defaults,
    {
      name: 'testroute1'
      reverse: (_) -> "path/#{_.foo}/#{_.bar}"
      path: "path/:foo/:bar", fn: (res, req) ->
        console.log 'dontcare'
    },{
      name: 'testroute2'
      path: "path/:foo/:bar", fn: (res, req) ->
        console.log 'dontcare'
    }
  )

  test.ok(router, 'no router')
  test.equal(router.reverse('testroute1', foo: "FOO", bar: "BAR"), "path/FOO/BAR")
  test.equal(router.reverse('testroute2', foo: "FOO", bar: "BAR"), "path/FOO/BAR")
  test.done()
