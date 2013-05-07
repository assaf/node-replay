URL = require("url")


# Simple proxy that spits all request URLs to the console if the debug settings is true.
#
# Example
#   replay.use replay.logger(exports)
#   replay.debug = true
logger = (settings)->
  return (request, callback)->
    replay = request.replay
    logger = replay.logger
    logger.log "Replay: Requesting #{request.method} #{URL.format(request.url)}"
    request.on "response", (response)->
      logger.log "Replay: Received #{response.statusCode} #{URL.format(request.url)}"
    request.on "error", (error)->
      unless replay.isIgnored(request.url.hostname)
        replay.emit("error", error)

    callback()
    return

module.exports = logger
