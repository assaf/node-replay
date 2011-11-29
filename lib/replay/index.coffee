{ EventEmitter } = require("events")
HTTP = require("http")
File = require("fs")


{ Replayer } = require("./replayer")


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


clone = (object)->
  result = {}
  for x, y of object
    result[x] = y
  return result


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

    @request = httpRequest.call(HTTP, @options)
    @request.on "continue", =>
      @emit "continue"
    @request.on "error", (error)=>
      @emit "error", error
    @request.on "response", (response)=>
      hostname = @options.hostname || "#{@options.host}:#{@options.port || 80}"
      pathname = @options.path || "/"
      @response = recordings.resolve(hostname, pathname) || new CaptureResponse(hostname, pathname, response)
      @emit "response", @response
      if @callback
        @callback @response
    @request.on "socket", (socket)=>
      @emit "socket", socket
    @request.on "upgrade", (response, socket, head)=>
      @emit "upgrade", response, socket, head

    if @timeout
      @request.setTimeout @timeout[0], @timeout[1]
    if @nodelay
      @request.setNoDelay @nodelay[0]
    if @keepAlive
      @request.setSocketKeepAlive @keepAlive[0], @keepAlive[1]
    if @parts
      for part in @parts
        @request.write part[0], part[1]
    @request.end()
    return

  abort: ->
    if @request
      @request.abort()
    return


{ Stream } = require("stream")


# Captures output of HTTP response for later replay.
class CaptureResponse extends Stream
  constructor: (@hostname, @pathname, @http)->
    @httpVersion = @http.httpVersion
    @statusCode = @http.statusCode
    @headers = @http.headers
    @http.on "data", (chunk)=>
      @_chunks ||= []
      @_chunks.push chunk
      @emit "data", chunk
    @http.on "end", =>
      @trailers = @http.trailers
      @emit "end"
      @_save()
    @http.on "close", =>
      @emit "close"

  setEncoding: (@_encoding)->
    @http.setEncoding @_encoding

  pause: ->
    @http.pause()
  
  resume: ->
    @http.resume()

  _save: ->
    serialized =
      version:  @httpVersion
      status:   @statusCode
      headers:  @headers
      encoding: @_encoding
      chunks:   @_chunks
      trailers: @trailers
    recordings.save @hostname, @pathname, serialized


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


class Recordings
  constructor: ->
    @by_hostname = {}
    @directory = "spec/replay"

  save: (hostname, pathname, object)->
    host = @for_host(hostname)
    host[pathname] = object
    File.writeFileSync("#{@directory}/#{hostname}.json", JSON.stringify(host, null, 2), "utf8")

  load: (hostname, pathname)->
    host = @for_host(hostname)
    return host[pathname]

  resolve: (hostname, pathname)->
    response = replayer.retrieve(url: "http://#{hostname}#{pathname}")
    if response
      return new ReplayResponse(response)
    recording = @load(hostname, pathname)
    if recording
      return new ReplayResponse(recording)
    else
      return null

  for_host: (hostname)->
    host = @by_hostname[hostname]
    unless host
      try
        json = File.readFileSync("#{@directory}/#{hostname}.json", "utf8")
        host = JSON.parse(json)
      catch error
        host = {}
      @by_hostname[hostname] = host
    return host


recordings = new Recordings
replayer   = new Replayer("#{__dirname}/../../spec/fixtures")

