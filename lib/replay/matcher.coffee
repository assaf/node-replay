# A matcher is a function that, given a request, returns an appropriate response or nothing.
#
# The most common use case is to calling `Matcher.fromMapping(mapping)`.
#
# The request consists of:
# url     - URL object
# method  - Request method (lower case)
# headers - Headers object (names are lower case)
# body    - Request body (for some requests)
#
# The response consists of:
# version   - HTTP version
# status    - Status code
# headers   - Headers object (names are lower case)
# body      - Array of body parts, each one a pair of content and optional encoding
# trailers  - Trailers object (names are lower case)


assert = require("assert")
URL = require("url")


# Simple implementation of a matcher.
#
# To create a matcher from request/response mapping use `fromMapping`.
class Matcher
  constructor: (request, response)->
    # Map requests to object properties.  We do this for quick matching.
    assert request.url, "I need at least a URL to match request to response"
    url = URL.parse(request.url)
    @hostname = url.hostname
    @port     = url.port
    @pathname = url.pathname
    @query    = url.query
    @method = (request.method && request.method.toLowerCase()) || "get"
    @headers = {}
    if request.headers
      for name, value of request.headers
        @headers[name.toLowerCase()] = value
    @body = request.body
    
    # Create a normalized response object that we return.
    assert response.status, "I need at least status code to define response"
    @response =
      version:  response.version || "1.1"
      status:   response.status && parseInt(response.status, 10)
      headers:  {}
      body:     []
      trailers: {}
    # Copy over header to response, downcase header names.
    if response.headers
      headers = @response.headers
      for name, value of response.headers
        headers[name.toLowerCase()] = value
    # Copy over body (string) or multiple body parts (strings or content/encoding pairs)
    if Array.isArray(response.body)
      body = @response.body
      for part in response.body
        if Array.isArray(part)
          response.body.push [part[0], part[1]]
        else
          response.body.push [part]
    else if response.body
      @response.body.push [response.body]
    # Copy over trailers to response, downcase trailers names.
    if response.trailers
      trailers = @response.trailers
      for name, value of response.trailers
        trailers[name.toLowerCase()] = value

  # Quick and effective matching. 
  match: (request)->
    { url, method, headers, body } = request
    return false if @hostname && @hostname != url.hostname
    return false if @port && @port != url.port
    return false if @pathname && @pathname != url.pathname
    return false if @query && @query != url.query
    return false unless @method == method || "get"
    for name, value of @headers
      return false if value != headers[name]
    return false if @body && @body != body
    return true


  # Returns new matcher function based on the supplied mapping.
  #
  # Mapping can contain `request` and `response` object.  As shortcut, mapping can specify `url` and `method` (optional)
  # directly, and also any of the response properties.
  @fromMapping: (mapping)->
    assert !!mapping.url ^ !!mapping.request, "Mapping must specify url value or request object"
    if mapping.url
      request =
        url:    mapping.url
        method: mapping.method
    else
      request = mapping.request
    matcher = new Matcher(request, mapping.response || mapping)
    return (request)->
      if matcher.match(request)
        return matcher.response


exports.Matcher = Matcher
