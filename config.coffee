# Basic config
exports.site = {
  title: 'harmonic'
}
exports.debug = true
exports.catch_uncaught_errors = true
exports.cookie_secret = 'SOME SECRET STRING'
exports.server = {
  host: '0.0.0.0'
  port: 8126
}

# Experimental
# MongoDB db/index ensure.
exports.mongo = {
  host: 'localhost'
  port: 27017
  db: 'harmonic_default_db'
  dbs: {} # defined below
}

# Setup indices here.
exports.mongo.dbs[exports.mongo.db] = {
  #  'COLLECTION1': null
  #  'COLLECTION2': [
  #    [['fieldname1'], {}]
  #    [{fieldname2: 1}, {unique: true}]
  #  ]

  # For apps/auth
  # TODO find a better way to configure apps
  user: [
    [{name: 1}, {unique: true}]
  ]
}

# Nogg logging
exports.logging = {
  'default': [
    {file: 'logs/app.log',    level: 'debug'},
    {file: 'stdout',          level: 'warn'}]
  'harmonic.db': [
    {file: 'logs/db.log',     level: 'debug'},
    {file: 'stdout',          level: 'warn'}]
  'apps': [
    {file: 'logs/app.log',    level: 'info'},
    {file: 'stdout',          level: 'debug'}]
}
