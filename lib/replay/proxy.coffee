# A proxy is a function that receives two arguments, a request object and a callback.
#
# If it can generate a respone, it calls callback with null and the response object.  Otherwise, either calls callback
# with no arguments, or with an error to stop the processing chain.
#
# The request consists of:
# url     - URL object
# method  - Request method (lower case)
# headers - Headers object (names are lower case)
# body    - Request body, an array of body part/encoding pairs
#
# The response consists of:
# version   - HTTP version
# status    - Status code
# headers   - Headers object (names are lower case)
# body      - Array of body parts
# trailers  - Trailers object (names are lower case)
#
# This file defines ProxyRequest, which acts as an HTTP ClientRequest that captures the request and passes it to the
# proxy chain, and ProxyResponse, which acts as an HTTP ClientResponse, playing back a response it received from the
# proxy.
#
# No actual proxies defined here.


assert = require("assert")
HTTP = require("http")
Stream = require("stream")
URL = require("url")


# HTTP client request that captures the request and sends it down the processing chain.
class ProxyRequest extends HTTP.ClientRequest
  constructor: (options = {}, @proxy)->
    @method = (options.method || "get").toLowerCase()
    [host, port] = (options.host || options.hostname).split(":")
    @url = URL.parse("http://#{host || "localhost"}:#{options.port || port || 80}#{options.path || "/"}")
    @headers = {}
    if options.headers
      for n,v of options.headers
        @headers[n.toLowerCase()] = v

  setHeader: (name, value)->
    assert !@ended, "Already called end"
    assert !@body, "Already wrote body parts"
    @headers[name.toLowerCase()] = value

  getHeader: (name)->
    return @headers[name.toLowerCase()]

  removeHeader: (name)->
    assert !@ended, "Already called end"
    assert !@body, "Already wrote body parts"
    delete @headers[name.toLowerCase()]

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
    assert !@ended, "Already called end"
    @body ||= []
    @body.push [chunk, encoding]
    return

  end: (data, encoding)->
    assert !@ended, "Already called end"
    if data
      @write data, encoding
    @ended = true

    @proxy this, (error, captured)=>
      process.nextTick =>
        if error
          @emit "error", error
        else if captured
          response = new ProxyResponse(captured)
          @emit "response", response
          process.nextTick ->
            response.resume()
        else
          error = new Error("Connection to #{URL.format(@url)} refused: not recording and no network access")
          error.code = "ECONNREFUSED"
          error.errno = "ECONNREFUSED"
          @emit "error", error
    return

  abort: ->


clone = (object)->
  result = {}
  for x, y of object
    result[x] = y
  return result


# HTTP client response that plays back a captured response.
class ProxyResponse extends Stream
  constructor: (captured)->
    @httpVersion = captured.version || "1.1"
    @statusCode  = captured.status || "200"
    @headers     = clone(captured.headers)
    @trailers    = clone(captured.trailers)
    @_body       = captured.body.slice(0)
    @readable    = true

  pause: ->
    @_paused = true

  resume: ->
    @_paused = false
    process.nextTick =>
      return if @_paused || !@_body
      part = @_body.shift()
      if part
        if @_encoding
          chunk = new Buffer(part).toString(@_encoding)
        else
          chunk = part
        @emit "data", chunk
        @resume()
      else
        @_body = null
        @readable = false
        @_done = true
        @emit "end"

  setEncoding: (@_encoding)->

  @notFound: (url)->
    return new ProxyResponse(status: 404, body: ["No recorded request/response that matches #{URL.format(url)}"])


exports.ProxyRequest = ProxyRequest
