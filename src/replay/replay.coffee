# The Replay module holds global configution properties and methods.


Catalog           = require("./catalog")
Chain             = require("./chain")
{ EventEmitter }  = require("events")
logger            = require("./logger")
passThrough       = require("./pass_through")
recorder          = require("./recorder")


# Supported modes.
MODES = ["bloody", "cheat", "record", "replay"]



# Instance properties:
#
# catalog   - The catalog is responsible for loading pre-recorded responses
#             into memory, from where they can be replayed, and storing captured responses.
#
# chain     - The proxy chain.  Essentially an array of proxies through which
#             each request goes, from first to last.  You generally don't need
#             to use this unless you decide to reconstruct your own chain.
#
#             When adding new proxies, you probably want those executing ahead
#             of any existing proxies (certainly the pass-through proxy), so
#             you'll want to prepend them.  The `use` method will prepend a
#             proxy to the chain.
#
# debug     - Set this to true to dump more information to the console, or run
#             with DEBUG=true
#
# fixtures  - Main directory for replay fixtures.
#
# logger    - Logger to use (defaults to console)
#
# mode      - The mode we're running in, one of:
#   bloody  - Allow outbound HTTP requests, don't replay anything.  Use this to
#             test your code against changes to 3rd party API.
#   cheat   - Allow outbound HTTP requests, replay captured responses.  This
#             mode is particularly useful when new code makes new requests, but
#             unstable yet and you don't want these requests saved.
#   record  - Allow outbound HTTP requests, capture responses for future
#             replay.  This mode allows you to capture and record new requests,
#             e.g. when adding tests or making code changes.
#   replay  - Do not allow outbound HTTP requests, replay captured responses.
#             This is the default mode and the one most useful for running tests
#
# silent    - If true do not emit errors to logger
class Replay extends EventEmitter
  constructor: (mode)->
    unless ~MODES.indexOf(mode)
      throw new Error("Unsupported mode '#{mode}', must be one of #{MODES.join(", ")}.")
    @chain = new Chain()
    @debug = !!process.env.DEBUG
    @fixtures = null
    @logger =
      log:    (message)=>
        if @debug
          console.log message
      error:  (message)=>
        if @debug || !@silent
          console.error message
    @mode = mode
    # localhost servers. pass requests directly to host, and route to 127.0.0.1.
    @_localhosts = { localhost: true }
    # allowed servers. allow network access to any servers listed here.
    @_allowed = { }
    # ignored servers. do not contact or record.
    @_ignored = { }
    @catalog = new Catalog(this)

    # Automatically emit connection errors and such, also prevent process from failing.
    @on "error", (error, url)=>
      @logger.error "Replay: #{error.message || error}"


  # Addes a proxy to the beginning of the processing chain, so it executes ahead of any existing proxy.
  #
  # Example
  #     replay.use replay.logger()
  use: (proxy)->
    @chain.prepend(proxy)

  # Allow network access to this host.
  allow: (hosts...)->
    for host in hosts
      @_allowed[host] = true
      delete @_ignored[host]
      delete @_localhosts[host]

  # True if this host is allowed network access.
  isAllowed: (host)->
    return !!@_allowed[host]

  # Ignore network access to this host.
  ignore: (hosts...)->
    for host in hosts
      @_ignored[host] = true
      delete @_allowed[host]
      delete @_localhosts[host]

  # True if this host is on the ignored list.
  isIgnored: (host)->
    return !!@_ignored[host]

  # Treats this host as localhost: requests are routed directory to 127.0.0.1, no replay.  Useful when you want to send
  # requests to the test server using its production host name.
  #
  # Example
  #     replay.localhost "www.example.com"
  localhost: (hosts...)->
    for host in hosts
      @_localhosts[host] = true
      delete @_allowed[host]
      delete @_ignored[host]

  # True if this host should be treated as localhost.
  isLocalhost: (host)->
    return !!@_localhosts[host]


replay = new Replay(process.env.REPLAY || "replay")


# The default processing chain (from first to last):
# - Pass through requests to localhost
# - Log request to console is `deubg` is true
# - Replay recorded responses
# - Pass through requests in bloody and cheat modes
passWhenBloodyOrCheat = (request)->
  return replay.isAllowed(request.url.hostname) ||
         (replay.mode == "cheat" && !replay.isIgnored(request.url.hostname))
passToLocalhost = (request)->
  return replay.isLocalhost(request.url.hostname) ||
         replay.mode == "bloody"

replay.use passThrough(passWhenBloodyOrCheat)
replay.use recorder(replay)
replay.use logger(replay)
replay.use passThrough(passToLocalhost)


module.exports = replay
