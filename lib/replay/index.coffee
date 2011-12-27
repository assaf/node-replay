HTTP          = require("http")
Catalog       = require("./catalog")
Chain         = require("./chain")
ProxyRequest  = require("./proxy")
logger        = require("./logger")
passThrough   = require("./pass_through")
replay        = require("./replay")


Replay =
  # The proxy chain.  Essentially an array of proxies through which each request goes, from first to last.  You
  # generally don't need to use this unless you decide to reconstruct your own chain.
  #
  # When adding new proxies, you probably want those executing ahead of any existing proxies (certainly the pass-through
  # proxy), so you'll want to prepend them.  The `use` method will prepend a proxy to the chain.
  chain: new Chain

  # Set this to true to dump more information to the console, or run with DEBUG=true
  debug: process.env.DEBUG == "true"

  # Main directory for replay fixtures.
  fixtures: null

  # The mode we're running in, one of:
  # bloody  - Allow outbound HTTP requests, don't replay anything.  Use this to test your code against changes to 3rd
  #           party API.
  # cheat   - Allow outbound HTTP requests, replay captured responses.  This mode is particularly useful when new code
  #           makes new requests, but unstable yet and you don't want these requests saved.
  # record  - Allow outbound HTTP requests, capture responses for future replay.  This mode allows you to capture and
  #           record new requests, e.g. when adding tests or making code changes.
  # replay  - Do not allow outbound HTTP requests, replay captured responses.  This is the default mode and the one most
  #            useful for running tests
  mode: process.env.REPLAY || "replay"

  # Addes a proxy to the beginning of the processing chain, so it executes ahead of any existing proxy.
  #
  # Example
  #     replay.use replay.logger()
  use: (proxy)->
    Replay.chain.prepend proxy

# The catalog is responsible for loading pre-recorded responses into memory, from where they can be replayed, and
# storing captured responses.
Replay.catalog = new Catalog(Replay)


# The default processing chain (from first to last):
# - Pass through requests to localhost
# - Log request to console is `deubg` is true
# - Replay recorded responses
# - Pass through requests in bloody and cheat modes
Replay.use passThrough(-> Replay.mode == "cheat")
Replay.use replay(Replay)
Replay.use logger(Replay)
Replay.use passThrough((request)-> request.url.hostname == "localhost" || Replay.mode == "bloody")


HTTP.request = (options, callback)->
  request = new ProxyRequest(options, Replay.chain.start)
  if callback
    request.once "response", (response)->
      callback response
  return request


module.exports = Replay
