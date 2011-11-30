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
    # Create entry in cache.  Even if empty, saves us from looking next time.
    matchers = @matchers[host] ||= []
    @basedir ||= Path.resolve(@settings.fixtures)

    # Start by looking for directory and loading each of the files.
    pathname = "#{@basedir}/#{host}"
    if Path.existsSync(pathname)
      files = File.readdirSync(pathname)
      for file in files
        json = File.readFileSync("#{pathname}/#{file}", "utf8")
        for mapping in JSON.parse(json)
          matchers.push Matcher.fromMapping(mapping)

    # Load individual JSON file.
    filename = "#{@basedir}/#{host}.json"
    if Path.existsSync(filename)
      json = File.readFileSync(filename, "utf8")
      for mapping in JSON.parse(json)
        matchers.push Matcher.fromMapping(mapping)
    
    return matchers


exports.Catalog = Catalog
