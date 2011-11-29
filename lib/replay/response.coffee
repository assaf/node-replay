{ Stream } = require("stream")


clone = (object)->
  result = {}
  for x, y of object
    result[x] = y
  return result


# Returns from replayer, even if we're just passing response through (recording mode).
class ReplayResponse extends Stream
  constructor: (@_captured)->
    @httpVersion = @_captured.version
    @statusCode  = @_captured.status
    @headers     = clone(@_captured.headers)
    @_index      = 0
    @readable    = true
    @resume()

  pause: ->
    @_paused = true

  resume: ->
    @_paused = false
    process.nextTick =>
      return if @_paused || @_done
      chunk = @_captured.chunks && @_captured.chunks[@_index]
      if chunk
        if @_encoding != @_captured.encoding
          chunk = new Buffer(chunk, @_captured.encoding).toString(@_encoding)
        @emit "data", chunk
        ++@_index
        @resume()
      else
        @readable = false
        @_done = true
        @trailers = clone(@_captured.trailers)
        @emit "end"

  setEncoding: (@_encoding)->


# Used to capture actual HTTP response for later replay.
class CaptureResponse
  constructor: (@request, @parts)->

  capture: (callback)->
    @request.on "response", (response)=>
      captured =
        version:  response.httpVersion
        status:   response.statusCode
        headers:  {}
        body:     []
        trailers: {}
      headers = captured.headers
      for name, value of response.headers
        headers[name.toLowerCase()] = value

      response.on "data", (chunk)->
        captured.body.push [chunk]
      response.on "end", ->
        trialers = captured.trailers
        for name, value of response.trailers
          trailers[name.toLowerCase()] = value
        callback null, captured

    @request.on "error", (error)->
      callback error

    if @parts
      for part in @parts
        @request.write @parts[0], @parts[1]
    @request.end()


exports.CaptureResponse = CaptureResponse
exports.ReplayResponse  = ReplayResponse
