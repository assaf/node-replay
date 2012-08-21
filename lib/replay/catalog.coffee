assert  = require("assert")
File    = require("fs")
Path    = require("path")
Matcher = require("./matcher")
_       = require("underscore")
{puts,inspect} = require("util")

mkdir = (pathname, callback)->
  Path.exists pathname, (exists)->
    if exists
      callback null
      return
    parent = Path.dirname(pathname)
    Path.exists parent, (exists)->
      if exists
        File.mkdir pathname, callback
      else
        mkdir parent, ->
          File.mkdir pathname, callback


# Only these request headers are stored in the catalog.
REQUEST_HEADERS = [/^accept/, /^authorization/, /^content-type/, /^host/, /^if-/, /^x-/]


class Catalog
  constructor: (@settings)->
    # We use this to cache host/host:port mapped to array of matchers.
    @matchers = {}

  find: (host)->
    # Return result from cache.
    matchers = @matchers[host]
    if matchers
      return matchers

    # Start by looking for directory and loading each of the files.
    pathname = "#{@basedir}/#{host}"
    unless Path.existsSync(pathname)
      return
    stat = File.statSync(pathname)
    if stat.isDirectory()
      files = File.readdirSync(pathname)
      for file in files
        matchers = @matchers[host] ||= []
        mapping = @_read("#{pathname}/#{file}")
        matchers.push Matcher.fromMapping(host, mapping)
    else
      matchers = @matchers[host] ||= []
      mapping = @_read(pathname)
      matchers.push Matcher.fromMapping(host, mapping)

    return matchers

  save: (host, request, response, callback)->
    matcher = Matcher.fromMapping(host, request: request, response: response)
    matchers = @matchers[host] ||= []
    matchers.push matcher

    uid = +new Date
    tmpfile = "/tmp/node-replay.#{uid}"
    pathname = "#{@basedir}/#{host}"
    console.log "Creating  #{pathname}"
    mkdir pathname, (error)->
      return callback error if error
      filename = "#{pathname}/#{uid}"

      try
        file = File.createWriteStream(tmpfile, encoding: "utf-8")
        file.write "#{request.method.toUpperCase()} #{request.url.path || "/"}\n"
        writeHeaders file, request.headers, REQUEST_HEADERS
        file.write "\n"
        if request.body
          request.body.map(([chunk, encoding]) -> file.write(chunk))
          file.write "\n\n"
        # Response part
        file.write "#{response.status || 200} HTTP/#{response.version || "1.1"}\n"
        writeHeaders file, response.headers
        file.write "\n"
        for part in response.body
          file.write part
        file.end ->
          File.rename tmpfile, filename, callback
          callback null
      catch error
        callback error

  @prototype.__defineGetter__ "basedir", ->
    @_basedir ?= Path.resolve(@settings.fixtures || "fixtures")
    return @_basedir

  _read: (filename)->
    parse_request = (request)->
      assert request, "#{filename} missing request section"
      [head, body...] = request.split(/\n\n/)
      body = body.join("\n\n")
      [method_and_path, header_lines...] = head.split(/\n/)
      if /\sREGEXP\s/.test(method_and_path)
        [method, raw_regexp] = method_and_path.split(" REGEXP ")
        [_, in_regexp, flags] = raw_regexp.match(/^\/(.+)\/(i|m|g)?$/)
        regexp = new RegExp(in_regexp, flags || "")
      else
        [method, path] = method_and_path.split(/\s/)
      assert method && (path || regexp), "#{filename}: first line must be <method> <path>"
      headers = parseHeaders(filename, header_lines, REQUEST_HEADERS)
      return { url: path || regexp, method: method, headers: headers, body: body }


    parse_response = (response)->
      if response
        [head, body...] = response.split(/\n\n/)
        body = body.join("\n\n")
        [status_line, header_lines...] = head.split(/\n/)
        status = parseInt(status_line.split()[0], 10)
        version = status_line.match(/\d.\d$/)
        headers = parseHeaders(filename, header_lines)
      return { status: status, version: version, headers: headers, body: body }

    [request, responseHeader, response] = File.readFileSync(filename, "utf-8").split(/\n\n(\d{3} HTTP\/.*)/)
    return { request: parse_request(request), response: parse_response(responseHeader + response) }

# Parse headers from header_lines.  Optional argument `only` is an array of
# regular expressions; only headers matching one of these expressions are
# parsed.  Returns a object with name/value pairs.
parseHeaders = (filename, header_lines, only = null)->
  headers = Object.create(null)
  for line in header_lines
    continue if line == ""
    [_, name, value] = line.match(/^(.*?)\:\s+(.*)$/)
    continue if only && !match(name, only)

    key = (name || "").toLowerCase()
    value = (value || "").trim().replace(/^"(.*)"$/, "$1")
    if Array.isArray(headers[key])
      headers[key].push value
    else if headers[key]
      headers[key] = [headers[key], value]
    else
      headers[key] = value
  return headers


# Write headers to the File object.  Optional argument `only` is an array of
# regular expressions; only headers matching one of these expressions are
# written.
writeHeaders = (file, headers, only = null)->
  for name, value of headers
    continue if only && !match(name, only)
    if Array.isArray(value)
      for item in value
        file.write "#{name}: #{item}\n"
    else
      file.write "#{name}: #{value}\n"


# Returns true if header name matches one of the regular expressions.
match = (name, regexps)->
  for regexp in regexps
    if regexp.test(name)
      return true
  return false


module.exports = Catalog
