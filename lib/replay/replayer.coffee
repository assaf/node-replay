File = require("fs")
Path = require("path")
{ Matcher } = require("./matcher")


class Replayer
  constructor: ->
    @matchers = {}

  process: (request, capture, callback)->
    { url } = request
    host = if !url.port || url.port.toString() == "80" then url.hostname else "#{url.hostname}:#{url.port}"
    try
      matchers = @_retrieve(host)
    catch error
      callback error
      return
    if matchers
      for matcher in matchers
        response = matcher(request)
        if response
          callback null, response

    if @_fallback
      @_fallback.retrieve request, capture, callback
      return
    if @_recording
      capture (error, response)->
        unless error
          @_store host, request, response
        callback error, response
    return

  chain: (fallback)->
    if @_fallback
      @_fallback.chain(fallback)
    else
      @_fallback = fallback
    return this

  recording: (recording = true)->
    @_recording = recording
    return this

  _retrieve: (host)->
    return @matchers[host]

  _store: (request, response)->
    { url } = request
    matcher = Matcher.fromMapping(request, response)
    host = if !url.port || url.port.toString() == "80" then url.hostname else "#{url.hostname}:#{url.port}"
    @matchers[host] ||= []
    @matchers[host].push matcher

  @fromFixtures = (basedir)->
    return new FixtureReplayer(basedir)


class FixtureReplayer extends Replayer
  constructor: (basedir)->
    Replayer.apply(this)
    @basedir = Path.resolve(basedir)

  _retrieve: (host)->
    # We store array of matchers or null if file doesn't exist.
    matchers = @matchers[host]
    if matchers || matchers == null
      return matchers

    try
      json = File.readFileSync(Path.resolve(@basedir, "#{host}.json"), "utf8")
      matchers = []
      for mapping in JSON.parse(json)
        matchers.push Matcher.fromMapping(mapping)
      @matchers[host] = matchers
    catch error
      if error.code == "ENOENT"
        @matchers[host] = null
      else
        throw error
    return matchers



exports.Replayer = Replayer
