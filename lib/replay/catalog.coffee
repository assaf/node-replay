assert = require("assert")
File = require("fs")
Path = require("path")
{ Matcher } = require("./matcher")


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
        file.write request.url.path || "/"
        file.write "\n"
        for name, value of request.headers
          # TODO: quote me
          file.write "#{name}: #{value}\n"
        file.write "\n"
        # Response part
        file.write "#{response.status || 200} HTTP/#{response.version || "1.1"}\n"
        for name, value of response.headers
          # TODO: quote me
          file.write "#{name}: #{value}\n"
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
    [request, response, body...] = File.readFileSync(filename, "utf-8").split(/\n\n/)
    assert request, "#{filename} missing request section"
    request =
      pathname: request.split(/\n/)[0]

    assert response, "#{filename} missing response section"
    [status_line, header_lines...] = response.split(/\n/)
    status = status_line.split()[0]
    version = status_line.match(/\d.\d$/)
    headers = {}
    for line in header_lines
      [_, name, value] = line.match(/^(.*?)\:\s+(.*)$/)
      assert name && value, "#{filename}: can't make sense of header line #{line}"
      headers[name] = value
    response =
      status:   status
      version:  version
      headers:  headers
      body:     body.join("\n\n")

    return { request: request, response: response }


exports.Catalog = Catalog
