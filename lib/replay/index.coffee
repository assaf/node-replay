{ EventEmitter } = require("events")
HTTP = require("http")
File = require("fs")
URL = require("url")


{ CaptureResponse } = require("./capture")
{ Replay } = require("./replay")


# True if network access allowed.
exports.networkAccess = false
# True to record requests for playback later on.
exports.record = true


# Capture original HTTP request before we replace with replay code.
httpRequest = HTTP.request
# And there it comes ...
HTTP.request = (options, callback)->
  # No special handling for localhost request.
  if options.host == "localhost"
    return httpRequest.apply(HTTP, arguments)
  if exports.record
    return new ReplayRequest(options, callback)
  if exports.networkAccess
    return httpRequest.apply(HTTP, arguments)
  if callback
    process.nextTick ->
      callback new Error("VCR: network access disabled. To enable, set VCR.networkAccess = true")
  request = new EventEmitter
  request.write = request.end = request.abort = request.setTimeout = request.setNoDelay =
    request.setSocketKeepAlive = request.setHeader = request.getHeader = request.removeHeader = ->
  return request



# HTTP client request that allows us to capture the request
class ReplayRequest extends HTTP.ClientRequest
  constructor: (options = {}, @callback)->
    # Duplicate headers and options.
    @headers = {}
    if options.headers
      for n,v of options.headers
        @headers[n] = v
    @options = { headers: @headers }
    for name in ["host", "hostname", "port", "socketPath", "method", "path", "auth"]
      value = options[name]
      if value
        @options[name] = value

  setHeader: (name, value)->
    unless @parts
      @headers[name] = value
    return value

  getHeader: (name)->
    return @headers[name]

  removeHeader: (name)->
    unless @parts
      delete @headers[name]
    return

  setTimeout: (timeout, callback)->
    @timeout = [timeout, callback]
    return

  setNoDelay: (nodelay = true)->
    @nodelay = [nodelay]
    return

  setSocketKeepAlive: (enable = false, initial)->
    @keepAlive = [enable, initial]
    return

  write: (chunk, encoding)->
    @parts ||= []
    @parts.push [chunk, encoding]
    return

  end: (data, encoding)->
    if data
      @write data, encoding

    capture = new CaptureResponse(httpRequest.call(HTTP, @options), @parts)
    capture = capture.capture.bind(capture)
    request =
      url:  URL.parse("#{@options.protocol || "http"}://#{@options.host}#{@options.path}")
    replay.process request, capture, (error, response)=>
      if error
        @emit "error", error
        return
      if response
        @emit "response", response
      else
        @emit "error", new Error("Not able to access #{request}")
    return

  abort: ->


replay   = Replay.fromFixtures("#{__dirname}/../../spec/fixtures")
