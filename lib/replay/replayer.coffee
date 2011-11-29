# Replayer is able to record and  reply responses.  Can be chained.


assert = require("assert")
File = require("fs")
Path = require("path")
URL = require("url")


class Replayer
  constructor: (basedir)->
    @basedir = Path.resolve(basedir)
    @hosts = {}


  # Retrieve response structure matching the request structure.
  # 
  # Request specifies:
  # url     - Request url
  # method  - Request method
  # headers - Request headers
  # body    - Request body
  retrieve: (request)->
    return unless request.url
    url = URL.parse(request.url)
    filename = if !url.port || url.port.toString() == "80" then url.hostname else "#{url.hostname}:#{url.port}"
    # Retrieve mapping for that resource
    matchers = @hosts[filename]
    unless matchers
      try
        json = File.readFileSync(Path.resolve(@basedir, "#{filename}.json"), "utf8")
        matchers = []
        for mapping in JSON.parse(json)
          matchers.push new RequestMatcher(mapping)
      catch error
        if error.code == "ENOENT"
          if @fallback
            return @callback.retrieve(request)
          matchers = []
        else
          throw error
      @hosts[filename] = matchers

    for matcher in matchers
      if matcher.match(url)
        return matcher.response

    if @fallback
      return @callback.retrieve(request)
    return


class RequestMatcher
  constructor: (mapping)->
    if mapping.url
      url = URL.parse(mapping.url)
      @hostname = url.hostname
      @port     = url.port
      @pathname = url.pathname
      @query    = url.query
    else
      @hostname = request.hostname
      @port     = request.port
      @pathname = request.pathname
      @query    = request.query
    assert @hostname, "Mapping must specify at least hostname to match"

    response = mapping.response || mapping
    @response =
      version:  "1.1"
      status:   mapping.status && parseInt(mapping.status, 10)
      headers:  mapping.headers || {}
      body:     @chunk(mapping.body)
      trailers: mapping.trailers || {}
    assert @response.status, "Mapping must specify at least response status code"

  match: (url, headers, body)->
    return false if @hostname && @hostname != url.hostname
    return false if @port && @port != url.port
    return false if @pathname && @pathname != url.pathname
    return false if @query && @query != url.query
    return true

  chunk: (body)->
    unless body
      return []
    if Array.isArray(body)
      return body
    return [[body.toString(), "utf8"]]


exports.Replayer = Replayer
