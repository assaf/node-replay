assert = require("assert")
File = require("fs")
Path = require("path")
{ Matcher } = require("./matcher")


class Catalog
  constructor: (@settings)->
    # We use this to cache host/host:port mapped to array of matchers.
    @matchers = {}

  find: (host)->
    # Return result from cache.  
    matchers = @matchers[host]
    if matchers
      return matchers

    # We need a base directory to load files from.
    unless @settings.fixtures
      return
    @basedir ||= Path.resolve(@settings.fixtures)

    # Start by looking for directory and loading each of the files.
    pathname = "#{@basedir}/#{host}"
    unless Path.existsSync(pathname)
      return
    stat = File.statSync(pathname)
    if stat.isDirectory()
      files = File.readdirSync(pathname)
      for file in files
        matchers = @matchers[host] ||= []
        mapping = @read("#{pathname}/#{file}")
        matchers.push Matcher.fromMapping(host, mapping)
    else
      matchers = @matchers[host] ||= []
      mapping = @read(pathname)
      matchers.push Matcher.fromMapping(host, mapping)
    
    return matchers

  read: (filename)->
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
      body:     body

    return { request: request, response: response }


exports.Catalog = Catalog
