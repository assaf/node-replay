{ Catalog } = require("./catalog")


exports.replay = (settings)->
  catalog = new Catalog(settings)
  return (request, callback)->
    host = request.url.hostname
    if request.url.port && request.url.port != "80"
      host += ":#{request.url.port}"
    matchers = catalog.find(host)
    if matchers
      for matcher in matchers
        response = matcher(request)
        if response
          callback null, response
          return
    callback null

