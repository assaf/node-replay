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
    if Path.existsSync(pathname)
      files = File.readdirSync(pathname)
      for file in files
        matchers = @matchers[host] ||= []
        json = File.readFileSync("#{pathname}/#{file}", "utf8")
        for mapping in JSON.parse(json)
          matchers.push Matcher.fromMapping(host, mapping)

    # Load individual JSON file.
    filename = "#{@basedir}/#{host}.json"
    if Path.existsSync(filename)
      matchers = @matchers[host] ||= []
      json = File.readFileSync(filename, "utf8")
      for mapping in JSON.parse(json)
        matchers.push Matcher.fromMapping(host, mapping)
    
    return matchers


exports.Catalog = Catalog
