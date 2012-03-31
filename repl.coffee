# Core module.
# Holds the core application logic and all interactions with JSREPL.
# Emits events so other modules can hook into.
$ = jQuery

$.extend REPLIT,
  Init: ->
    @jsrepl = new JSREPL {
      input: $.proxy @InputCallback, @
      output: $.proxy @OutputCallback, @
      result: $.proxy @ResultCallback, @
      error: $.proxy @ErrorCallback, @
      progress: $.proxy @OnProgress, @
      timeout:
        time: 15000,
        callback: =>
          a = confirm 'The program is taking too long to finish. Do you want to stop it?'
          @LoadLanguage @current_lang.system_name if a
          return a
    }

    # Init console.
    @jqconsole = @$consoleContainer.jqconsole '', '   ', '.. '
    @$console = @$consoleContainer.find '.jqconsole'

    # Init editor.
    @$editor = @$editorContainer.find '#editor-widget'
    if not @ISMOBILE
      @editor = ace.edit 'editor-widget'
      @editor.setTheme 'ace/theme/textmate'
      @editor.renderer.setHScrollBarAlwaysVisible false
      @$run.click =>
        # TODO(max99x): Expose state properly from jqconsole.
        if @jqconsole.state is 2  # STATE_PROMPT
          @jqconsole.AbortPrompt()
          @Evaluate REPLIT.editor.getSession().getValue()

    @current_lang = null
    @current_lang_name = null
    @inited = true

  # Load a given language by name.
  LoadLanguage: (lang_name, callback=$.noop) ->
    @$this.trigger 'language_loading', [lang_name]
    @current_lang = @jsrepl.getLangConfig lang_name.toLowerCase()
    # Hold the name for saving and such.
    @current_lang.system_name = lang_name

    #Load Ace mode.
    if not @ISMOBILE
      EditSession = require("ace/edit_session").EditSession
      UndoManager = require("ace/undomanager").UndoManager
      session = new EditSession ''
      session.setUndoManager new UndoManager
      ace_mode = @Languages[lang_name].ace_mode
      if ace_mode?
        # jQuery deferred object for getting ace mode.
        ace_mode_ajax = $.getScript ace_mode.script, =>
          mode = require(ace_mode.module).Mode
          session.setMode new mode
          @editor.setSession session
      else
        # No ace mode found create a resolved deferred.
        ace_mode_ajax = jQuery.Deferred().resolve()
        textMode = require("ace/mode/text").Mode
        session.setMode new textMode
        @editor.setSession session

    # Empty out the history and prompt.
    @jqconsole.Reset()
    # Register character matchings in jqconsole for the current language.
    for [open, close], index in @current_lang.matchings
      @jqconsole.RegisterMatching open, close, 'matching-' + index

    # Register shortcuts.
    @jqconsole.RegisterShortcut 'Z', =>
      @jqconsole.AbortPrompt()
      @StartPrompt()
    @jqconsole.RegisterShortcut 'L', =>
      @OpenPage 'languages'
    @jqconsole.RegisterShortcut 'G', =>
      @OpenPage 'examples'
    @jqconsole.RegisterShortcut 'H', =>
      @OpenPage 'help'
    @jqconsole.RegisterShortcut 'S', =>
      $('#button-save').click()
    @jqconsole.RegisterShortcut 'A', =>
      @jqconsole.MoveToStart();
    @jqconsole.RegisterShortcut 'E', =>
      @jqconsole.MoveToEnd();

    # Load the language engine from jsREPL.
    @jsrepl.loadLanguage lang_name.toLowerCase(), =>
      # Continue only when the ace mode retrieval is done.
      $.when(ace_mode_ajax).then =>
        @StartPrompt()
        @$this.trigger 'language_loaded', [lang_name]
        @jqconsole.Write @Languages[lang_name].header + '\n'
        callback()

  # Receives the result of a command evaluation.
  #   @arg result: The user-readable string form of the result of an evaluation.
  ResultCallback: (result) ->
    if result
      result = result + '\n' if result[-1] isnt '\n'
      @jqconsole.Write '=> ' + result, 'result'
    @StartPrompt()
    @$this.trigger 'result', [result]
  # Receives an error message resulting from a command evaluation.
  #   @arg error: A message describing the error.
  ErrorCallback: (error) ->
    if typeof error == 'object'
      error = error.message
    error = error + '\n' if error[-1] isnt '\n'
    @jqconsole.Write String(error), 'error'
    @StartPrompt()
    @$this.trigger 'error', [error]
  # Receives any output from a language engine. Acts as a low-level output
  # stream or port.
  #   @arg output: The string to output. May contain control characters.
  #   @arg cls: An optional class for styling the output.
  OutputCallback: (output, cls) ->
    if output
      @jqconsole.Write output, cls
      @$this.trigger 'output', [output]
      return undefined
  # Receives a request for a string input from a language engine. Passes back
  # the user's response asynchronously.
  #   @arg callback: The function called with the string containing the user's
  #     response.
  InputCallback: (callback) ->
    @jqconsole.Input (result) =>
      try
        callback result
        @$this.trigger 'input', [result]
      catch e
        @ErrorCallback e
    @$this.trigger 'input_request', [callback]
    return undefined

  Evaluate: (command) ->
    if command
      @jsrepl.eval command
      @$this.trigger 'eval', [command]
    else
      @StartPrompt()

  # Shows a command prompt in the console and waits for input.
  StartPrompt: ->
    @jqconsole.Prompt true, $.proxy(@Evaluate, @), @jsrepl.checkLineEnd, true

$ ->
  REPLIT.Init()
