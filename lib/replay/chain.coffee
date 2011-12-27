class Chain
  append: (proxy)->
    fallback = @_fallback(proxy)
    if @last
      @last.next = fallback
    @last = fallback
    @first ||= fallback
    return this

  prepend: (proxy)->
    fallback = @_fallback(proxy)
    fallback.next = @first
    @first = fallback
    @last ||= fallback
    return this

  _fallback: (proxy)->
    fallback = (request, callback)=>
      proxy request, (error, response)=>
        if error || response
          callback error, response
          return
        if fallback.next
          fallback.next request, callback
        else
          callback null
    return fallback

  clear: ->
    @first = @last = null

  @prototype.__defineGetter__ "start", ->
    return @first

module.exports = Chain
