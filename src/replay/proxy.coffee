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


assert            = require("assert")
{ EventEmitter }  = require("events")
HTTP              = require("http")
HTTPS             = require("https")
Stream            = require("stream")
URL               = require("url")


# HTTP client request that captures the request and sends it down the processing chain.
class ProxyRequest extends HTTP.ClientRequest
  constructor: (options = {}, @proxy)->
    HTTP.IncomingMessage.call(this)
    @method       = (options.method || "GET").toUpperCase()
    protocol      = options.protocol || "http:"
    [host, port]  = (options.host || options.hostname).split(":")
    port          = options.port || port || (if protocol == "https:" then 443 else 80)
    @url          = URL.parse("#{protocol}//#{host || "localhost"}:#{port}#{options.path || "/"}", true)
    @auth         = options.auth
    @agent        = options.agent || (if protocol == "https:" then HTTPS.globalAgent else HTTP.globalAgent)
    @headers      = {}
    if options.headers
      for n,v of options.headers
        @headers[n.toLowerCase()] = if (v == null || v == undefined) then "" else v.toString()

  flushHeaders: ()->
    return

  setHeader: (name, value)->
    assert !@ended, "Already called end"
    assert !@body, "Already wrote body parts"
    @headers[name.toLowerCase()] = value
    return

  getHeader: (name)->
    return @headers[name.toLowerCase()]

  removeHeader: (name)->
    assert !@ended, "Already called end"
    assert !@body, "Already wrote body parts"
    delete @headers[name.toLowerCase()]
    return

  addTrailers: (trailers)->
    @trailers = trailers
    return

  setTimeout: (timeout, callback)->
    if (callback)
      setImmediate(callback)
    return

  setNoDelay: (nodelay = true)->
    return

  setSocketKeepAlive: (enable = false, initial)->
    return

  write: (chunk, encoding, callback)->
    assert !@ended, "Already called end"
    @body ||= []
    @body.push [chunk, encoding]
    if callback
      setImmediate(callback)

  end: (data, encoding, callback)->
    assert !@ended, "Already called end"

    if (typeof data == 'function')
      [callback, data] = [data, null]
    else if (typeof encoding == 'function')
      [callback, encoding] = [encoding, null]
    if data
      @body ||= []
      @body.push [data, encoding]
    @ended = true

    if (callback)
      setImmediate(callback)

    @proxy this, (error, captured)=>
      # We're not asynchronous, but clients expect us to callback later on
      setImmediate =>
        if error
          @emit "error", error
        else if captured
          response = new ProxyResponse(captured)
          @emit("response", response)
          response.resume()
        else
          error = new Error("#{@method} #{URL.format(@url)} refused: not recording and no network access")
          error.code = "ECONNREFUSED"
          error.errno = "ECONNREFUSED"
          @emit "error", error
    return

  flush: ->
    return

  abort: ->
    return


clone = (object)->
  result = {}
  for x, y of object
    result[x] = y
  return result


# HTTP client response that plays back a captured response.
class ProxyResponse extends Stream.Readable
  constructor: (captured)->
    Stream.Readable.call(this);
    @httpVersion      = captured.version || "1.1"
    @httpVersionMajor = @httpVersion.split(".")[0]
    @httpVersionMinor = @httpVersion.split(".")[1]
    @statusCode       = captured.statusCode || 200
    @statusMessage    = captured.statusMessage || HTTP.STATUS_CODES[@statusCode] || ""
    @headers          = clone(captured.headers)
    @rawHeaders       = (captured.rawHeaders || [].slice(0))
    # Not a documented property, but request seems to use this to look for HTTP parsing errors
    @connection       = new EventEmitter()

    @_body            = captured.body.slice(0)
    @once "end", =>
      @trailers    = clone(captured.trailers)
      @rawTrailers = (captured.rawTrailers || []).slice(0)
      @emit("close")

  _read: (size)->
    part = @_body.shift()
    if part
      @push(part[0], part[1])
    else
      @push(null)
    return

  setTimeout: (msec, callback)->
    if (callback)
      setImmediate(callback)
    return

  @notFound: (url)->
    return new ProxyResponse(status: 404, body: ["No recorded request/response that matches #{URL.format(url)}"])


module.exports = ProxyRequest
