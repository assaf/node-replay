HTTP = require("http")
{ Chain } = require("./chain")
{ ProxyRequest } = require("./proxy")
{ logger } = require("./logger")
{ passThrough } = require("./pass_through")
{ replay } = require("./replay")


# The proxy chain.  Essentially an array of proxies through which each request goes, from first to last.  You generally
# don't need to use this unless you decide to reconstruct your own chain.
#
# When adding new proxies, you probably want those executing ahead of any existing proxies (certainly the pass-through
# proxy), so you'll want to prepend them.  The `use` method will prepend a proxy to the chain.
exports.chain = new Chain

# Set this to true to dump more information to the console, or run with DEBUG=true
exports.debug = process.env.DEBUG == "true"

# Main directory for replay fixtures.
exports.fixtures = ""

# Set to true to enable network access.
exports.networkAccess = false

# Set to true to enable recording responses, or run with RECORD=true
exports.record = process.env.RECORD == "true"

# Addes a proxy to the beginning of the processing chain, so it executes ahead of any existing proxy.
#
# Example
#     replay.use replay.logger()
exports.use = (proxy)->
  exports.chain.prepend proxy


HTTP.request = (options, callback)->
  request = new ProxyRequest(options, exports.chain.start)
  if callback
    request.once "response", (response)->
      callback response
  return request


# The default processing chain (from first to last):
# - Pass through requests to localhost
# - Log request to console is `deubg` is true
# - Replay recorded responses
# - Pass through requests if `networkAccess` is true
exports.chain.append passThrough((request)-> request.url.hostname == "localhost")
exports.chain.append replay(exports)
exports.chain.append logger(exports)
exports.chain.append passThrough(-> exports.networkAccess)
