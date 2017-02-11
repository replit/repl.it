# Core module.
# Responsible for DOM initializations, and most interactions.
DEFAULT_CONTENT_PADDING = 200
FOOTER_HEIGHT = 30
HEADER_HEIGHT = 61
RESIZER_WIDTH = 8
DEFAULT_SPLIT = 0.5
CONSOLE_HIDDEN = 1
EDITOR_HIDDEN = 0
SNAP_THRESHOLD = 0.05
ANIMATION_DURATION = 700
MIN_PROGRESS_DURATION = 1
MAX_PROGRESS_DURATION = 1500
PROGRESS_ANIMATION_DURATION = 2000
TITLE_ANIMATION_DURATION = 300
DEFAULT_TITLE = 'Online Interpreter'
$ = jQuery

# jQuery plugin to disable text selection (x-browser).
# Used for dragging the resizer.
$.fn.disableSelection = ->
  @each ->
    $this = $(this)
    $this.attr 'unselectable', 'on'
    $this.css
      '-moz-user-select':'none'
      '-webkit-user-select':'none'
      'user-select':'none'
    $this.each -> this.onselectstart = -> return false
# jQuery plugin to enable text selection (x-browser).
$.fn.enableSelection = ->
  @each ->
    $this = $(this)
    $this.attr 'unselectable', ''
    $this.css
      '-moz-user-select': ''
      '-webkit-user-select': ''
      'user-select': ''
    $this.each -> this.onselectstart = null


$.extend REPLIT,
  RESIZER_WIDTH: RESIZER_WIDTH
  CONSOLE_HIDDEN: CONSOLE_HIDDEN
  EDITOR_HIDDEN: EDITOR_HIDDEN
  DEFAULT_CONTENT_PADDING: DEFAULT_CONTENT_PADDING
  split_ratio: if REPLIT.ISMOBILE then EDITOR_HIDDEN else DEFAULT_SPLIT 
  # NOTE: These should be synced with PAGES.workspace.width in pager.coffee.
  min_content_width: 500
  max_content_width: 3000
  content_padding: DEFAULT_CONTENT_PADDING
  last_progress_ratio: 0
  # Initialize the DOM (Runs before JSRPEL's load)
  InitDOM: ->
    @$doc_elem = $ 'html'
    # The main container holding the pages.
    @$container = $ '#main'
    # The container holding the editor widget and related elements.
    @$editorContainer = $ '#editor'
    # The container holding the console widget and related elements.
    @$consoleContainer = $ '#console'
    # An object holding all the resizer elements.
    @$resizer =
      l: $ '#resize-left'
      c: $ '#resize-center'
      r: $ '#resize-right'
    # The loading progress bar.
    @$progress = $ '#progress'
    @$progressFill = $ '#progress-fill'
    # An object holding unhider elements.
    @$unhider =
      editor: $ '#unhide-right'
      console: $ '#unhide-left'

    # Show the run button on hover.
    @$run = $ '#editor-run'
    @$editorContainer.mouseleave =>
      @$run.fadeIn 'fast'
    @$editorContainer.mousemove =>
      if @$run.is ':hidden' then @$run.fadeIn 'fast'
    @$editorContainer.keydown =>
      @$run.fadeOut 'fast'

    # Initialaize the column resizers.
    @InitSideResizers()
    @InitCenterResizer()
    # Attatch unhiders functionality.
    @InitUnhider()
    # Fire the onresize method to do initial resizing
    @OnResize()
    # When the window change size, call the container's resizer.
    mobile_timer = null
    $(window).bind 'resize', => 
      if @ISMOBILE
        mobile_timer = clearTimeout mobile_timer
        cb = =>
          width = document.documentElement.clientWidth
          REPLIT.min_content_width =  width - 2 * RESIZER_WIDTH
          @OnResize()
        mobile_timer = setTimeout (=> @OnResize()), 300
      else
        @OnResize()

  # Attatches the resizers behaviors.
  InitSideResizers: ->
    $body = $ 'body'
    # For all resizers discard right clicks,
    # disable text selection on drag start.
    for _, $elem of @$resizer
      $elem.mousedown (e) ->
        if e.button != 0
          e.stopImmediatePropagation()
        else
          $body.disableSelection()

    # On start drag bind the mousemove functionality for right/left resizers.
    @$resizer.l.mousedown (e) =>
      $body.bind 'mousemove.side_resizer', (e) =>
        # The horizontal mouse position is simply half of the content_padding.
        # Subtract half of the resizer_width for better precision.
        @content_padding = ((e.pageX - (RESIZER_WIDTH / 2)) * 2)
        if @content_padding / $body.width() < SNAP_THRESHOLD
          @content_padding = 0
        @OnResize()
    @$resizer.r.mousedown (e) =>
      $body.bind 'mousemove.side_resizer', (e) =>
        # The mouse is on the right of the container, subtracting the horizontal
        # position from the page width to get the right number.
        @content_padding = ($body.width() - e.pageX - (RESIZER_WIDTH / 2)) * 2
        if @content_padding / $body.width() < SNAP_THRESHOLD
          @content_padding = 0
        @OnResize()

    # When stopping the drag unbind the mousemove handlers and enable selection.
    resizer_lr_release = ->
      $body.enableSelection()
      $body.unbind 'mousemove.side_resizer'
    @$resizer.l.mouseup resizer_lr_release
    @$resizer.r.mouseup resizer_lr_release
    $body.mouseup resizer_lr_release

  InitCenterResizer: ->
    # When stopping the drag or when the editor/console snaps into hiding,
    # unbind the mousemove event for the container.
    resizer_c_release = =>
      @$container.enableSelection()
      @$container.unbind 'mousemove.center_resizer'

    # When start drag for the center resizer bind the resize logic.
    @$resizer.c.mousedown (e) =>
      @$container.bind 'mousemove.center_resizer', (e) =>
        # Get the mouse position relative to the container.
        left = e.pageX - (@content_padding / 2) + (RESIZER_WIDTH / 2)
        # The ratio of the editor-to-console is the relative mouse position
        # divided by the width of the container.
        @split_ratio = left / @$container.width()
        # If the smaller split ratio as small as 0.5% then we must hide the element.
        if @split_ratio > CONSOLE_HIDDEN - SNAP_THRESHOLD
          @split_ratio = CONSOLE_HIDDEN
          # Stop the resize drag.
          resizer_c_release()
        else if @split_ratio < EDITOR_HIDDEN + SNAP_THRESHOLD
          @split_ratio = EDITOR_HIDDEN
          # Stop the resize drag.
          resizer_c_release()
        # Run the window resize handler to recalculate everything.
        @OnResize()

    # Release when:
    @$resizer.c.mouseup resizer_c_release
    @$container.mouseup resizer_c_release
    @$container.mouseleave resizer_c_release

  InitUnhider: ->
    # Show unhider on mouse movement and hide on keyboard interactions.
    getUnhider = =>
      if @split_ratio not in [CONSOLE_HIDDEN, EDITOR_HIDDEN] then return $ []
      side = if @split_ratio == CONSOLE_HIDDEN then 'console' else 'editor'
      return @$unhider[side]
    $('body').mousemove =>
      unhider = getUnhider()
      if unhider.is ':hidden' then unhider.fadeIn 'fast'
    @$container.keydown =>
      unhider = getUnhider()
      if unhider.is ':visible' then unhider.fadeOut 'fast'

    bindUnhiderClick = ($elem, $elemtoShow) =>
      $elem.click (e) =>
        # Hide the unhider.
        $elem.hide()
        # Set the split ratio to the default split.
        @split_ratio = DEFAULT_SPLIT
        # Show the hidden element.
        $elemtoShow.show()
        # Show the center resizer.
        @$resizer.c.show()
        # Recalculate all sizes.
        @OnResize()

    bindUnhiderClick @$unhider.editor, @$editorContainer
    bindUnhiderClick @$unhider.console, @$consoleContainer

  # Updates the progress bar's width and color.
  OnProgress: (percentage) ->
    ratio = percentage / 100.0
    # TODO: Find out why this happens.
    if ratio < @last_progress_ratio then return
    duration = (ratio - @last_progress_ratio) * PROGRESS_ANIMATION_DURATION
    @last_progress_ratio = ratio
    duration = Math.max(duration, MIN_PROGRESS_DURATION)
    duration = Math.min(duration, MAX_PROGRESS_DURATION)
    fill = @$progressFill
    fill.animate width: percentage + '%',
      duration: Math.abs(duration),
      easing: 'linear',
      step: (now, fx) ->
        ratio = now / 100.0
        # A hardcoded interpolation equation between:
        #           red       orange     yellow     green
        #    top: #fa6e43 -> #fab543 -> #fad643 -> #88f20d
        # bottom: #f2220c -> #f26c0c -> #f2a40c -> #c7fa44
        red_top = Math.round(if ratio < 0.75
          250
        else
          250 + (199 - 250) * ((ratio - 0.75) / 0.25))
        red_bottom = Math.round(if ratio < 0.75
          242
        else
          250 + (136 - 250) * ((ratio - 0.75) / 0.25))

        green_top = Math.round(if ratio < 0.25
          110 + (181 - 110) * (ratio / 0.25)
        else
          181 + (250 - 181) * ((ratio - 0.25) / 0.75))
        green_bottom = Math.round(34 + (242 - 34) * ratio)

        blue_top = 67
        blue_bottom = 12

        top = "rgb(#{red_top}, #{green_top}, #{blue_top})"
        bottom = "rgb(#{red_bottom}, #{green_bottom}, #{blue_bottom})"

        if $.browser.webkit
          fill.css 'background-image': "url('/images/progress.png'), -webkit-gradient(linear, left top, left bottom, from(#{top}), to(#{bottom}))"
        else if $.browser.mozilla
          fill.css 'background-image': "url('/images/progress.png'), -moz-linear-gradient(top, #{top}, #{bottom})"
        else if $.browser.opera
          fill.css 'background-image': "url('/images/progress.png'), -o-linear-gradient(top, #{top}, #{bottom})"
        fill.css 'background-image': "url('/images/progress.png'), linear-gradient(top, #{top}, #{bottom})"

  # Resize containers on each window resize, split ratio change or
  # content padding change.
  OnResize: ->
    # Calculate container height and width.
    documentWidth = document.documentElement.clientWidth
    documentHeight = document.documentElement.clientHeight
    height = documentHeight - HEADER_HEIGHT - FOOTER_HEIGHT 
    width = documentWidth - @content_padding
    innerWidth = width - 2 * RESIZER_WIDTH

    # Clamp width.
    if innerWidth < @min_content_width
      innerWidth = @min_content_width
    else if innerWidth > @max_content_width
      innerWidth = @max_content_width
    width = innerWidth + 2 * RESIZER_WIDTH

    # Resize container and current page.
    @$container.css
      width: width
      height: height

    $('.page:visible').css
      width: innerWidth

    if $('.page:visible').is '#content-workspace'
      @ResizeWorkspace innerWidth, height

  ResizeWorkspace: (innerWidth, height) ->
    # Calculate editor and console sizes.
    editor_width = Math.floor @split_ratio * innerWidth
    console_width = innerWidth - editor_width
    if @split_ratio not in [CONSOLE_HIDDEN, EDITOR_HIDDEN]
      editor_width -= RESIZER_WIDTH / 2
      console_width -= RESIZER_WIDTH / 2

    # Apply the new sizes.
    @$resizer.c.css
      left: editor_width
    @$editorContainer.css
      width: editor_width
      height: height
    @$consoleContainer.css
      width: console_width
      height: height

    # Check if console/editor was meant to be hidden.
    if @split_ratio == CONSOLE_HIDDEN
      @$consoleContainer.hide()
      @$resizer.c.hide()
      @$unhider.console.show()
    else if @split_ratio == EDITOR_HIDDEN
      @$editorContainer.hide()
      @$resizer.c.hide()
      @$unhider.editor.show()

    # Calculate paddings if any.
    console_hpadding = @$console.innerWidth() - @$console.width()
    console_vpadding = @$console.innerHeight() - @$console.height()
    editor_hpadding = @$editor.innerWidth() - @$editor.width()
    editor_vpadding = @$editor.innerHeight() - @$editor.height()
    # Resize the console/editor widgets.
    @$editor.css 'width', @$editorContainer.innerWidth() - editor_hpadding
    @$editor.css 'height', @$editorContainer.innerHeight() - editor_vpadding

    # Call to Ace editor resize.
    @$editor.resize() if not @ISMOBILE

  changeTitle: (title) ->
    $title = $ '#title'
    curr_title = $title.text().trim()
    return if not title or curr_title == title
    document.title = "repl.it - #{title}"
    if curr_title != '' and curr_title != DEFAULT_TITLE
      $title.fadeOut TITLE_ANIMATION_DURATION, ->
        $title.text title
        $title.fadeIn TITLE_ANIMATION_DURATION
    else
      $title.text title

$ ->
  if REPLIT.ISIOS then $('html, body').css 'overflow', 'hidden'
  REPLIT.$this.bind 'language_loading', (_, system_name) ->
    REPLIT.$progress.animate opacity: 1, 'fast'
    REPLIT.$progressFill.css width: 0
    REPLIT.last_progress_ratio = 0

    # Update footer links.
    lang = REPLIT.Languages[system_name.toLowerCase()]
    $about = $ '#language-about-link'
    $engine = $ '#language-engine-link'
    $links = $ '#language-engine-link, #language-about-link'

    $links.animate opacity: 0, 'fast', ->
      $about.text 'about ' + lang.name
      $about.attr href: lang.about_link

      $engine.text lang.name + ' engine'
      $engine.attr href: lang.engine_link

      $links.animate opacity: 1, 'fast'

  REPLIT.$this.bind 'language_loaded', (e, lang_name) ->
    REPLIT.OnProgress 100
    REPLIT.$progress.animate opacity: 0, 'fast'


  # When the device orientation change adapt the workspace to the new width.
  check_orientation = ->
    cb = ->
      width = document.documentElement.clientWidth
      REPLIT.min_content_width =  width - 2 * RESIZER_WIDTH
      REPLIT.OnResize()
      # iPhone scrolls to the left when changing orientation to portrait.
      $(window).scrollLeft 0
    # Android takes time to know its own width!
    setTimeout cb, 300
  $(window).bind 'orientationchange', check_orientation
  if REPLIT.ISMOBILE then check_orientation()
  REPLIT.InitDOM()
  $('#buttons').tooltip
    selector: '.button'
    placement: 'bottom'
