URL = require("url")

# Simple proxy that spits all request URLs to the console if the debug settings is true.
#
# Example
#     replay.use replay.logger(exports)
#     replay.debug = true
exports.logger = (settings)->
  return (request, callback)->
    if settings.debug
      console.log "Requesting #{URL.format(request.url)}"
    callback()
