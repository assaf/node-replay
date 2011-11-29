DNS = require("dns")
{ Replay } = require("../lib/replay")


# Redirect all HTTP requests to localhost
DNS.lookup = (domain, callback)->
  callback null, "127.0.0.1", 4


# Directory to load fixtures from.
Replay.fixtures = "#{__dirname}/fixtures"


exports.assert = require("assert")
exports.vows   = require("vows")
exports.HTTP   = require("http")
exports.Replay = Replay
