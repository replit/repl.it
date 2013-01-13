# Extension module.
# Responsible for generating cross-browser hash change events.

$ = jQuery
HASH_SEPARATOR = ':'
popStateSupported = 'onpopstate' of window
hashchangeSupported = 'onhashchange' of window
window_loaded = false
hash_states = ['','']
initial_hash = window.location.hash.slice 1

$.extend REPLIT,
  HASH_SEPARATOR: HASH_SEPARATOR
  setHash: (index, target) ->
    cb = ->
      return if hash_states[index]? is target
      if not target?
        target = index
        window.location.hash = target if target isnt ''
      else
        # We want to set the location hash without changing the states.
        # Save the old state.
        _oldstate = hash_states[index]
        hash_states[index] = target
        # Construct the new hash.
        hash = hash_states.join(':')
        hash = '' if hash is ':'
        # Restore the original state so that hashchange event can be triggered
        # by the hash_check function. 
        hash_states[index] = _oldstate
        window.location.hash = hash
      $(window).trigger 'hashchange'
    if not window_loaded
      $(window).bind (-> setTimeout((-> REPLIT.setHash index, target), 0))
    else
      cb()

$(window).bind 'load', ->
  window_loaded = true
  REPLIT.setHash initial_hash
  hash_check = ->
    hash = window.location.hash.slice 1
    hash_splitted = hash.split(':')
    hash_1 = hash_splitted[0]
    hash_2 = hash_splitted[1]
    if hash_splitted.length == 3
      REPLIT.$this.trigger 'hashchange:2', [hash_splitted[2]] 
      return true
    if hash_states[0] isnt hash_1
      hash_states[0] = hash_1
      REPLIT.$this.trigger 'hashchange:0', [hash_1]
    if hash_states[1] isnt hash_2
      hash_states[1] = hash_2
      REPLIT.$this.trigger 'hashchange:1', [hash_2]
    
    return true
      
  if popStateSupported
    $(window).bind 'popstate', hash_check
    $(window).trigger 'popstate'
  else if hashchangeSupported
    $(window).bind 'hashchange', hash_check
    $(window).trigger 'hashchange'
  else
    lastHash = null
    checkHash = ->
      hash = window.location.hash.slice 1
      if hash isnt lastHash
        lastHash = hash
        hash_check()
    setInterval checkHash, 250
