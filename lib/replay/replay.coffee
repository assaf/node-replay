# The Replay module holds global configution properties and methods.


Catalog       = require("./catalog")
Chain         = require("./chain")
logger        = require("./logger")
passThrough   = require("./pass_through")
recorder      = require("./recorder")


# Supported modes.
MODES = ["bloody", "cheat", "record", "replay"]


# Localhost servers. Pass requests directly to host, and route to 127.0.0.1.
localhosts = { localhost: true }
# Allowed servers. Allow network access to any servers listed here.
allowed = { }


Replay =
  # The proxy chain.  Essentially an array of proxies through which each request goes, from first to last.  You
  # generally don't need to use this unless you decide to reconstruct your own chain.
  #
  # When adding new proxies, you probably want those executing ahead of any existing proxies (certainly the pass-through
  # proxy), so you'll want to prepend them.  The `use` method will prepend a proxy to the chain.
  chain: new Chain()

  # Set this to true to dump more information to the console, or run with DEBUG=true
  debug: !!process.env.DEBUG

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

  # Treats this host as localhost: requests are routed directory to 127.0.0.1, no replay.  Useful when you want to send
  # requests to the test server using its production host name.
  #
  # Example
  #     replay.localhost "www.example.com"
  localhost: (host)->
    localhosts[host] = true
    delete allowed[host]

  # True if this host should be treated as localhost.
  isLocalhost: (host)->
    return !!localhosts[host]

  # Allow network access to this host.
  allow: (host)->
    delete localhosts[host]
    allowed[host] = true

  # True if this host is allowed network access.
  isAllowed: (host)->
    return !!allowed[host]


# The catalog is responsible for loading pre-recorded responses into memory, from where they can be replayed, and
# storing captured responses.
Replay.catalog = new Catalog(Replay)


# The default processing chain (from first to last):
# - Pass through requests to localhost
# - Log request to console is `deubg` is true
# - Replay recorded responses
# - Pass through requests in bloody and cheat modes
Replay.use passThrough (request)->
  return Replay.isAllowed(request.url.hostname) || Replay.mode == "cheat"
Replay.use recorder(Replay)
Replay.use logger(Replay)
Replay.use passThrough (request)->
  return Replay.isLocalhost(request.url.hostname) || Replay.mode == "bloody"


unless ~MODES.indexOf(Replay.mode)
  throw new Error("Unsupported mode '#{Replay.mode}', must be one of #{MODES.join(", ")}.")


module.exports = Replay
