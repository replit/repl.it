# Extension module.
# Encapsulates for all session/state loading saving logic.
# TODO(amasad): Graceful localStorage degradation to cookies.
$ = jQuery
WAIT_BETWEEN_SAVES = 2000
SHARE_TEMPLATE =
  twitter: ->
    text = 'Check out my REPL session - '
    related = 'replit'
    url = window.location.href
    uri = $.param {
      text
      url
      related
    }
    """
      <a href="https://twitter.com/share?#{uri}" target="_blank"></a>
    """

  facebook: ->
    """
      <a href="javascript:var d=document,f='http://www.facebook.com/share',l=d.location,e=encodeURIComponent,p='.php?src=bm&v=4&i=1315186262&u='+e(l.href)+'&t='+e(d.title);1;try{if (!/^(.*\.)?facebook\.[^.]*$/.test(l.host))throw(0);share_internal_bookmarklet(p)}catch(z) {a=function() {if (!window.open(f+'r'+p,'sharer','toolbar=0,status=0,resizable=1,width=626,height=436'))l.href=f+p};if (/Firefox/.test(navigator.userAgent))setTimeout(a,0);else{a()}}void(0)"></a>
    """

  # Unofficial!
  gplus: ->
    text = 'Check out my REPL session - ' + window.location.href
    text = encodeURI text
    """
      <a href="https://m.google.com/app/plus/x/bggo8s9j8yqo/?v=compose&content=#{text}&login=1&pli=1&hideloc=1" target="_blank"></a>
    """

$.extend REPLIT,
  session:
    eval_history: []
# Resets application to its initial state (handler for language_loaded event).
reset_state = (e, lang_name) ->
  localStorage.setItem 'lang_name', lang_name
  $('#replay-button').hide()
  @session = {}
  @session.eval_history = []
  Router.change_base '/'

$ ->
  # If there exists a REPLIT_DATA variable, then we are in a saved session.
  if REPLIT_DATA?
    # Load the language specified by the incoming session data.
    REPLIT.current_lang_name = REPLIT_DATA.language
    REPLIT.LoadLanguage REPLIT_DATA.language, ->
      # Set the editor text.
      REPLIT.editor.getSession().setValue REPLIT_DATA.editor_text if not REPLIT.ISMOBILE
      # Get the session data.
      REPLIT.session.id = REPLIT_DATA.session_id
      REPLIT.session.rid = REPLIT_DATA.revision_id
      REPLIT.session.saved_eval_history = REPLIT_DATA.eval_history
      # Show the replay button.
      $('#replay-button').show()
      # Delete the incoming session data from the server since we have
      # extracted everything we neeed.
      delete window['REPLIT_DATA']
      # On each language load after this one reset the state.
      REPLIT.$this.bind 'language_loaded', reset_state
  else if not REPLIT.url_language
    # We are not in a saved session.
    # Safely bind the reset state function.
    REPLIT.$this.bind 'language_loaded', reset_state
    lang_name = localStorage.getItem('lang_name')
    if lang_name?
      REPLIT.loading_saved_lang = true
      REPLIT.current_lang_name = lang_name

      # We have a saved local settings for language to load. Delay this until
      # the Analytics modules has set its hook so it can catch language loading.
      $ ->
        REPLIT.LoadLanguage lang_name
    else
      # This is the first visit; show language overlay.
      $('#languages-back').bind 'click.language_modal', (e) ->
        e.stopImmediatePropagation()
        return false
      $('#content-languages .language-group li').bind 'click.language_modal', (e) ->
        REPLIT.Modal false

      REPLIT.$this.bind 'language_loaded.language_modal', (e) ->
        $('#languages-back').unbind 'click.language_modal'
      Router.navigate '/languages'
      REPLIT.Modal true

  # Click handler for the replay button.
  $('#replay-button').click (e) ->
    # Get the history comming from the server.
    history = REPLIT.session.saved_eval_history
    locked = false
    locked_queue = []
    index = -1
    # Executes a command from history and waits for the result to continue
    # with the next command.
    handler = ->
      if not locked
        index++
        if history[index]?
          # Set the prompt text to the command in question.
          REPLIT.jqconsole.SetPromptText history[index]
          # Remove multiline handler from jqconsole to ensure it doesn't
          # continue to the next line.
          _multiline = REPLIT.jqconsole.multiline_callback
          REPLIT.jqconsole.multiline_callback = undefined
          # Simulate an enter button on jqconsole.
          REPLIT.jqconsole._HandleEnter()
          # Reassign the multiline handler.
          REPLIT.jqconsole.multiline_callback = _multiline
        else
          # There is no more commands; unbind the handler.
          REPLIT.$this.unbind 'result', handler
          REPLIT.$this.unbind 'error', handler
          # We are done with the eval history from the server; delete it.
          delete REPLIT.session['saved_eval_history']
      else
        locked_queue.push handler

    input_lock = ->
      locked = true

    input_unlock = ->
      locked = false
      fn = locked_queue.shift()
      setTimeout fn, 100 if fn?

    REPLIT.$this.bind 'result', handler
    REPLIT.$this.bind 'error', handler
    REPLIT.$this.bind 'input', input_unlock
    REPLIT.$this.bind 'input_request', input_lock
    # Initiate the first handler to start executing history commands.
    handler()
    # This button can only be clicked once. Now hide it.
    $(this).hide()

  saveSession = (e) ->
    # Can't save if we haven't selected a language yet.
    if not REPLIT.current_lang? then return
    # Get the post data to save.
    post_data =
      language: REPLIT.current_lang.system_name
      editor_text: REPLIT.editor.getSession().getValue() if not REPLIT.ISMOBILE
      eval_history: JSON.stringify REPLIT.session.eval_history
      console_dump: REPLIT.jqconsole.Dump();
      
    # If we are already REPLing on a saved session, get its id.
    post_data.id = REPLIT.session.id if REPLIT.session.id?
    # Do the actual save request.
    $.post '/save', post_data, (data) ->
      {session_id, revision_id} = data
      $savebox = $('#save-box')
      # Update URL.
      if revision_id > 0
        Router.change_base "/#{session_id}/#{revision_id}"
      else
        Router.change_base "/#{session_id}"
      # Update IDs.
      REPLIT.session.id = session_id
      REPLIT.session.rid = revision_id

      # Render social share links.
      $savebox.find('li.twitter a').replaceWith SHARE_TEMPLATE.twitter()
      $savebox.find('li.facebook a').replaceWith SHARE_TEMPLATE.facebook()
      $savebox.find('li.gplus a').replaceWith SHARE_TEMPLATE.gplus()
      $savebox.find('input').val window.location.href
      iframe_val = """
        <iframe width="100%" height="300" src="#{window.location.href}?embed=true" frameborder="0"></iframe>
      """
      $savebox.find('textarea').val iframe_val

      preview_link = "/embed-preview.html?embedded=#{encodeURIComponent(iframe_val)}"
      $savebox.find('#save-box-embed-test').attr('href', preview_link)
      $savebox.find('.downloads a.editor').attr 'href', "/download/editor/#{session_id}/#{revision_id}/"
      $savebox.find('.downloads a.repl').attr 'href', "/download/repl/#{session_id}/#{revision_id}/"
      $savebox.slideDown()
      $savebox.click (e) ->
        return e.stopPropagation()
      $('body').bind 'click.closesave', ->
        $savebox.slideUp()
        $('body').unbind('click.closesave')

      # Disable share button for a little while.
      unbindSaveButton()
      setTimeout bindSaveButton, WAIT_BETWEEN_SAVES

  bindSaveButton = -> $('#button-save').click saveSession
  unbindSaveButton = -> $('#button-save').unbind 'click'
  bindSaveButton()

  $('#save-box input').click -> $(this).select()
  $('#save-box textarea').click -> $(this).select()
  # When any command is evaled, save it in the eval_history array of the session
  # object, in order to send it to the server on save.
  REPLIT.$this.bind 'eval', (e, command) ->
    REPLIT.session.eval_history.push command
