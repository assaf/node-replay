require "../lib/replay"


# Redirect all HTTP requests to localhost
DNS = require("dns")
DNS.lookup = (domain, callback)->
  callback null, "127.0.0.1", 4



exports.assert = require("assert")
exports.vows   = require("vows")
exports.HTTP   = require("http")
