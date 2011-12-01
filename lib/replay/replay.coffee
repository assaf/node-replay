{ Catalog } = require("./catalog")


exports.replay = (settings)->
  catalog = new Catalog(settings)
  return (request, callback)->
    matchers = catalog.find(request.url.host)
    if matchers
      for matcher in matchers
        response = matcher(request)
        if response
          callback null, response
          return
    callback null

