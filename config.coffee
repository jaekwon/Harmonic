# Basic config
@site =
  title: 'harmonic'
@debug = true
@catch_uncaught_errors = true
@cookie_secret = 'SOME SECRET STRING'
@server =
  host: '0.0.0.0'
  port: 8126

# Database configuration
@database =
  uri: 'mongo://localhost:27017/somedb'

# Apps
@apps =
  default: 'apps/default'
  auth:    'apps/auth'
  sample:  'apps/sample'

# Logging
@logging =
  'default': [
    {file: 'logs/app.log',    level: 'debug'},
    {file: 'stdout',          level: 'warn'}]
  'harmonic.db': [
    {file: 'logs/db.log',     level: 'debug'},
    {file: 'stdout',          level: 'warn'}]
  'apps': [
    {file: 'logs/app.log',    level: 'info'},
    {file: 'stdout',          level: 'debug'}]
