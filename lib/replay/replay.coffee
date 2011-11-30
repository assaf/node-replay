# A replay is an object that is able to process requests and either record or replay responses.
#
# The `process` method is used to supply a request, optional capture mechanism (in record mode) and completion callback.
# It will either return a previously captured response, or capture and record a new response.
#
# This file includes `FixtureReplay`, an implementation that stores all captured request/response mappings in JSON files
# in a single directory.


File = require("fs")
Path = require("path")
URL = require("url")
{ Catalog } = require("./catalog")
{ Matcher } = require("./matcher")
{ Stream } = require("stream")


# Base replay is able to intercept requests, record and replay responses.
class Replay
  constructor: ->
    @matchers = {}
    @record = false

  process: (request, capture, callback)->
    { url } = request
    host = if !url.port || url.port.toString() == "80" then url.hostname else "#{url.hostname}:#{url.port}"
    # Load any suitable matchers for that host.  This may file (e.g. invalid fixture files), in which case we need to
    # capture the error and report it.
    try
      matchers = @_retrieve(host)
    catch error
      callback error
      return
    # If there are any matchers to replay responses, use them first.
    if matchers
      for matcher in matchers
        response = matcher(request)
        if response
          callback null, new ReplayResponse(response)
          return

    # Fallback on the next replay in the chain (e.g. API replay falls back on fixture replay)
    if @fallback
      @fallback.process request, capture, callback
      return

    # Last replay in the chain.  If capturing enabled, ask to capture the response and return it.  Otherwise, if we have
    # matchers for the host, we return 404 (nothing matching path).  If we have no matching for host, we simulate
    # connection error.
    if capture
      capture (error, response)->
        # In recording mode, store a mapping from request to response.  Otherwise, just pass the request through.
        if response && @record
          @_store request, response
        callback error, response && new ReplayResponse(response)
    else if matchers
      callback null, ReplayResponse.notFound(url)
    else
      callback null

  chain: (fallback)->
    if @fallback
      @fallback.chain(fallback)
    else
      @fallback = fallback
    return this

  recording: (record = true)->
    @record = !!record
    if @fallback
      @fallback.recording(@record)

  _retrieve: (host)->
    return @matchers[host]

  _store: (request, response)->
    { url } = request
    matcher = Matcher.fromMapping(request, response)
    host = if !url.port || url.port.toString() == "80" then url.hostname else "#{url.hostname}:#{url.port}"
    @matchers[host] ||= []
    @matchers[host].push matcher

  @fromFixtures = (basedir)->
    return new FixtureReplay(basedir)


# Implementation of `Replay` that captures all request/response mappings in JSON files in a single directory.
class FixtureReplay extends Replay
  constructor: (basedir)->
    Replay.apply(this)
    @catalog = new Catalog(Replay)

  _retrieve: (host)->
    return @catalog.find(host)


clone = (object)->
  result = {}
  for x, y of object
    result[x] = y
  return result


# Replay returns this object, an implementation of `http.ClientResponse` that is able to stream back a replayed
# response.
class ReplayResponse extends Stream
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
    return new ReplayResponse(status: 404, body: ["No recorded request/response that matches #{URL.format(url)}"])



exports.Replay = Replay
