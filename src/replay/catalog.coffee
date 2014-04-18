assert         = require("assert")
File           = require("fs")
Path           = require("path")
Matcher        = require("./matcher")
jsStringEscape = require("js-string-escape")

exists = File.exists || Path.exists
existsSync = File.existsSync || Path.existsSync


existsSync = File.existsSync || Path.existsSync


mkdir = (pathname, callback)->
  exists pathname, (found)->
    if found
      callback null
      return
    parent = Path.dirname(pathname)
    exists parent, (found)->
      if found
        File.mkdir pathname, callback
      else
        mkdir parent, ->
          File.mkdir pathname, callback


class Catalog
  constructor: (@settings)->
    # We use this to cache host/host:port mapped to array of matchers.
    @matchers = {}
    @_basedir = Path.resolve("fixtures")

  getFixturesDir: ->
    return @_basedir

  setFixturesDir: (dir)->
    @_basedir = Path.resolve(dir)
    @matchers = {}
    return

  find: (host)->
    # Return result from cache.
    matchers = @matchers[host]
    if matchers
      return matchers

    # Start by looking for directory and loading each of the files.
    # Look for host-port (windows friendly) or host:port (legacy)
    pathname = "#{@getFixturesDir()}/#{host.replace(":", "-")}"
    unless existsSync(pathname)
      pathname = "#{@getFixturesDir()}/#{host}"
    unless existsSync(pathname)
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
    request_headers = @settings.headers

    uid = +new Date + "" + Math.floor(Math.random() * 100000)
    tmpfile = "#{@getFixturesDir()}/node-replay.#{uid}"
    pathname = "#{@getFixturesDir()}/#{host.replace(":", "-")}"
    logger = request.replay.logger
    logger.log "Creating #{pathname}"
    mkdir pathname, (error)->
      return callback error if error
      filename = "#{pathname}/#{uid}"

      try
        file = File.createWriteStream(tmpfile, encoding: "utf-8")
        file.write "#{request.method.toUpperCase()} #{request.url.path || "/"}\n"
        writeHeaders file, request.headers, request_headers
        if request.body
          body = ""
          for chunks in request.body
            body += chunks[0]
          writeHeaders file, body: jsStringEscape(body)
        file.write "\n"
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

  _read: (filename)->
    request_headers = @settings.headers
    parse_request = (request)->
      assert request, "#{filename} missing request section"
      [method_and_path, header_lines...] = request.split(/\n/)
      if /\sREGEXP\s/.test(method_and_path)
        [method, raw_regexp] = method_and_path.split(" REGEXP ")
        [_, in_regexp, flags] = raw_regexp.match(/^\/(.+)\/(i|m|g)?$/)
        regexp = new RegExp(in_regexp, flags || "")
      else
        [method, path] = method_and_path.split(/\s/)
      assert method && (path || regexp), "#{filename}: first line must be <method> <path>"
      headers = parseHeaders(filename, header_lines, request_headers)
      body = headers["body"]
      delete headers["body"]
      return { url: path || regexp, method: method, headers: headers, body: body }


    parse_response = (response, body)->
      if response
        [status_line, header_lines...] = response.split(/\n/)
        status = parseInt(status_line.split()[0], 10)
        version = status_line.match(/\d.\d$/)
        headers = parseHeaders(filename, header_lines)
      return { status: status, version: version, headers: headers, body: body.join("\n\n") }

    [request, response, body...] = File.readFileSync(filename, "utf-8").split(/\n\n/)
    return { request: parse_request(request), response: parse_response(response, body) }


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
