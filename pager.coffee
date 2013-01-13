# Extension module.
# Responsible for page opening/closing/stacking.

$ = jQuery

ANIMATION_DURATION = 300
KEY_ESCAPE = 27
FIRST_LOAD = true

LANG_TEMPLATE =
  language_group: (data) ->
    {category, languages} = data
    """
    <div class="language-group">
      <div class="language-group-header">#{category}</div>
        <ul>
          #{(@language_entry(language) for language in languages).join('')}
        </ul>
      </div>
    </div>
  """

  language_entry: (data) ->
    {name, shortcut, system_name, tagline} = data
    shortcut_index = name.indexOf(shortcut)
    """
      <li data-lang="#{system_name}">
        <b>#{name[0...shortcut_index]}<em>#{shortcut}</em>#{name[shortcut_index + 1...]}:</b>&nbsp;
          #{tagline}
      </li>
    """

  render: ->
    html = []
    categories_order = [
      'Classic'
      'Practical'
      'Esoteric'
      'Web'
    ]
    template_data =
      Classic:
        category: 'Classic'
        languages: ['QBasic', 'Forth']
      Practical:
        category: 'Practical'
        languages: ['Ruby', 'Python', 'Lua', 'Scheme']
      Esoteric:
        category: 'Esoteric'
        languages: ['Emoticon', 'Brainfuck', 'LOLCODE', 'Unlambda', 'Bloop']
      Web:
        category: 'Web'
        languages: ['JavaScript', 'Traceur', 'Move', 'Kaffeine', 'CoffeeScript', 'Roy']

    for _, category of template_data
      for lang_name, index in category.languages
        lang = REPLIT.Languages[lang_name]
        lang.system_name = lang_name
        category.languages[index] = lang
    for category in categories_order
      html.push @language_group template_data[category]

    return html.join ''

LANGUAGES = {
  'ruby' : 'Ruby',
  'python' : 'Python',
  'lua' : 'Lua',
  'scheme' : 'Scheme',
  'emoticon' : 'Emoticon', 
  'brainfuck' : 'Brainfuck', 
  'lolcode' : 'LOLCODE', 
  'unlambda' : 'Unlambda', 
  'bloop' : 'Bloop', 
  'javascript' : 'JavaScript', 
  'traceur' : 'Traceur', 
  'move' : 'Move', 
  'kaffeine' : 'Kaffeine', 
  'coffeescript' : 'CoffeeScript', 
  'roy' : 'Roy'
}

PAGES =
  workspace:
    id: 'content-workspace'
    title: '$'
    min_width: 500
    width: 1000
    max_width: 3000
  languages:
    id: 'content-languages'
    title: 'Select a Language'
    min_width: 1080
    width: 1080
    max_width: 1400
  examples:
    id: 'content-examples'
    title: '$ Examples'
    min_width: 1000
    width: 1000
    max_width: 1400
  help:
    id: 'content-help'
    title: 'Help'
    min_width: 1000
    width: 1000
    max_width: 1400
  about:
    id: 'content-about'
    title: 'About Us'
    min_width: 600
    max_width: 600
    width: 600
  DEFAULT: 'workspace'

ALLOWED_IN_MODAL = ['help', 'about', 'languages']

$.extend REPLIT,
  modal: false
  Modal: (@modal)->
  LoadExamples: (file, container, callback) ->
    $examples_container = $ '#examples-' + container
    $('.example-group').remove()
    $.get file, (contents) =>
      # Parse examples.
      raw_examples = contents.split /\*{60,}/
      index = 0
      total = Math.floor raw_examples.length / 2
      while index + 1 < raw_examples.length
        name = raw_examples[index].replace /^\s+|\s+$/g, ''
        code = raw_examples[index + 1].replace /^\s+|\s+$/g, ''
        # Insert an example element and set up its click handler.
        example_element = $ """
          <div class="example-group example-#{total}">
            <div class="example-group-header">#{name}</div>
            <code>#{code}</code>
          </div>
        """
        $examples_container.append example_element
        example_element.click -> callback $('code', @).text()
        index += 2

  # The pages stacking on the screen.
  page_stack: []
  # Whether we are currently changing a page (to prevent interference).
  changing_page: false

  # Open a page by its name.
  OpenPage: (page_name, callback=$.noop) ->
    if @changing_page or (@modal and page_name not in ALLOWED_IN_MODAL) then return
    @changing_page = true
    page = PAGES[page_name]
    current_page = @page_stack[@page_stack.length - 1]

    # If the page actually exists and it's not the current one.
    if not page or current_page is page_name
      @changing_page = false
    else
      # Calculate and set title.
      lang_name = if @current_lang_name
        @Languages[@current_lang_name].name
      else
        ''
      $title = $ '#title'
      new_title = page.title.replace /\$/g, lang_name
      if current_page
        $title.fadeOut ANIMATION_DURATION, ->
          $title.text new_title
          $title.fadeIn ANIMATION_DURATION
      else
        $title.text new_title

      # Update widths to those of the new page.
      # We can't take into account mobile sizes, so just assign the whole screen
      # width. That's Ok, since our mobile layout fits the whole width.
      @min_content_width = if @ISMOBILE
        document.documentElement.clientWidth - 2 * @RESIZER_WIDTH
      else
        page.min_width
      @max_content_width = page.max_width

      # When the workspace is first loaded, don't mess up its default padding.
      if FIRST_LOAD and page_name is 'workspace'
        FIRST_LOAD = false
        page.width = document.documentElement.clientWidth - @DEFAULT_CONTENT_PADDING
      @content_padding = document.documentElement.clientWidth - page.width

      # Check if the page exists on our stack. If so splice out to be put
      # on top.
      index = @page_stack.indexOf page_name
      if index > -1
        @page_stack.splice index, 1
      # Put the page on top of the stack.
      @page_stack.push page_name
      hash_name = if page_name is PAGES.DEFAULT then '' else page_name
      REPLIT.setHash 1, hash_name

      # Calculate container width.
      outerWidth = page.width
      # HACK: Workspace doesn't account for resizers for some reason...
      if page_name isnt 'workspace' then outerWidth += 2 * @RESIZER_WIDTH

      done = =>
        @changing_page = false
        page.$elem.focus()
        callback()

      if current_page
        # Perform the animation.
        PAGES[current_page].width = $('.page:visible').width()
        # HACK: Workspace doesn't account for resizers for some reason..
        if current_page is 'workspace'
          PAGES[current_page].width += 2 * @RESIZER_WIDTH
        PAGES[current_page].$elem.fadeOut ANIMATION_DURATION, =>
          @$container.animate width: outerWidth, ANIMATION_DURATION, =>
            # We need to have the box actually displayed (if invisible) so the
            # width calculations inside OnResize() work.
            page.$elem.css width: page.width, display: 'block', opacity: 0
            @OnResize()
            page.$elem.animate opacity: 1, ANIMATION_DURATION, done
      else
        @$container.css width: outerWidth
        page.$elem.css width: page.width, display: 'block'
        @OnResize()
        done()

  # Close the top page and opens the page underneath if exists or just animates
  # Back to the original environment width.
  CloseLastPage: ->
    if @changing_page then return
    if @page_stack.length <= 1 then return
    closed_page = @page_stack[@page_stack.length - 1]
    @OpenPage @page_stack[@page_stack.length - 2], =>
      @page_stack.splice @page_stack.indexOf(closed_page), 1

$ ->
  # Render language selector.
  $('#content-languages').append LANG_TEMPLATE.render()

  # Load Examples
  REPLIT.$this.bind 'language_loading', (_, system_name) ->
    examples = REPLIT.Languages[system_name].examples
    if not REPLIT.ISMOBILE
      REPLIT.LoadExamples examples.editor, 'editor', (example) ->
        REPLIT.editor.getSession().doc.setValue example
        REPLIT.OpenPage 'workspace', ->
          REPLIT.editor.focus()
    REPLIT.LoadExamples examples.console, 'console', (example) ->
      REPLIT.jqconsole.SetPromptText example
      REPLIT.OpenPage 'workspace', ->
        REPLIT.jqconsole.Focus()

  # React to hash changes.
  REPLIT.$this.bind 'hashchange:1', (_, new_page) ->
    if not new_page then new_page = PAGES.DEFAULT
    if new_page of PAGES
      current_page = @page_stack[@page_stack.length - 1]
      if new_page isnt current_page
        if REPLIT.changing_page
          # Interrupt current page switching animation.
          $('.page').stop true, true
          @$container.stop true, true
          REPLIT.changing_page = false
        REPLIT.OpenPage new_page

  # react to language calling on default
  REPLIT.$this.bind 'hashchange:2', (_, lang_name) ->
    REPLIT.OpenPage 'workspace'
    return true

    console.log "works"
    REPLIT.current_lang_name = lang_name
    if lang_name of LANGUAGES
      REPLIT.current_lang_name = LANGUAGES[lang_name] 
      console.log REPLIT.current_lang_name
      if REPLIT.changing_page
        # Interrupt current page switching animation.
        $('.page').stop true, true
        @$container.stop true, true
        REPLIT.changing_page = false

      REPLIT.OpenPage 'workspace', =>
        REPLIT.LoadLanguage REPLIT.current_lang_name


  # Since we will be doing lots of animation and syncing, we better cache the
  # jQuery elements.
  for name, settings of PAGES
    settings.$elem = $("##{settings.id}")
    # If we are on a mobile set all default widths to 0 to invoke resizing
    # to the minimum which is already set to the width;
    if REPLIT.ISMOBILE and name isnt 'workspace' then settings.width = 0

  # Assign events.
  $body = $ 'body'
  $body.delegate '.page-close', 'click', -> REPLIT.CloseLastPage()
  $body.delegate '.language-group li', 'click', ->
    REPLIT.current_lang_name = $(@).data 'lang'
    REPLIT.OpenPage 'workspace', =>
      REPLIT.LoadLanguage REPLIT.current_lang_name

  # Bind page buttons.
  bindPageButtons = ->
    $('#button-examples').click ->
      # TODO(max99x): Expose state properly from jqconsole.
      if REPLIT.current_lang? and REPLIT.jqconsole.state is 2  # STATE_PROMPT
        $('#examples-editor').toggle REPLIT.split_ratio != REPLIT.EDITOR_HIDDEN
        $('#examples-console').toggle REPLIT.split_ratio != REPLIT.CONSOLE_HIDDEN
        REPLIT.OpenPage 'examples'
      return false
    $('#button-languages').click ->
      REPLIT.OpenPage 'languages'
      return false
    $('#logo').click ->
      REPLIT.OpenPage 'languages'
      return false
    $('#link-about').click ->
      REPLIT.OpenPage 'about'
      return false
    $('#button-help').click ->
      REPLIT.OpenPage 'help'
      return false
  unbindPageButtons = ->
    buttons = $('#button-examples, #button-languages, #link-about, #button-help')
    buttons.unbind 'click'
  bindPageButtons()

  # Disable buttons while a language is being loaded.
  REPLIT.$this.bind 'language_loading', unbindPageButtons
  REPLIT.$this.bind 'language_loaded', bindPageButtons

  # Bind page closing to Escape.
  $(window).keydown (e) ->
    if e.which == KEY_ESCAPE and $('.page:visible') isnt '#content-workspace'
      REPLIT.CloseLastPage()

  # Bind language selector hotkeys.
  $('#content-languages').keypress (e) ->
    if e.shiftKey or e.ctrlKey or e.metaKey then return
    letter = String.fromCharCode(e.which).toLowerCase()
    $('#content-languages li').each ->
      if $('em', $ @).text().toLowerCase() == letter
        $(@).click()
        return false
