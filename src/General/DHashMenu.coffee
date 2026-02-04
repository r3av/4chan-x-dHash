DHashMenu =
  init: ->
    # No global init needed, opened via Test menu
    return

  open: ->
    console.log "DHashMenu.open called"
    return if DHashMenu.overlay
    $.event 'CloseMenu'

    # Create overlay to center the dialog and darken the background
    DHashMenu.overlay = overlay = $.el 'div',
      id: 'overlay'

    # Create dialog using same ID as Settings to reuse its CSS
    DHashMenu.dialog = dialog = $.el 'div',
      id:   'fourchanx-settings'
      className: 'dialog'
    
    # 1. Navigation Header
    nav = $.el 'nav'
    sectionsList = $.el 'div', className: 'sections-list'
    $.add nav, sectionsList
    
    credits = $.el 'div', className: 'credits'
    closeLink = $.el 'a',
      href: 'javascript:;'
      className: 'close fa fa-times'
      title: 'Close'
    $.on closeLink, 'click', DHashMenu.close
    $.add credits, closeLink
    $.add nav, credits
    $.add dialog, nav

    # 2. Section Container
    sectionContainer = $.el 'div', className: 'section-container'
    sectionContent = $.el 'section'
    $.add sectionContainer, sectionContent
    $.add dialog, sectionContainer

    # 3. Tabs
    tabs = [
      {title: 'Main', cb: DHashMenu.main}
      {title: 'Data', cb: DHashMenu.data}
    ]

    links = []
    for tab in tabs
      link = $.el 'a',
        className: "tab-#{tab.title.toLowerCase()}"
        textContent: tab.title
        href: 'javascript:;'
      
      # Use closure to capture 'tab'
      do (tab) ->
         $.on link, 'click', -> DHashMenu.openTab(tab, dialog)

      links.push link, $.tn ' | '
    links.pop() # remove last separator
    $.add sectionsList, links

    # 4. Attach Events
    $.on window,  'beforeunload', DHashMenu.close
    $.on overlay, 'click', DHashMenu.close
    $.on dialog,  'click', (e) -> e.stopPropagation()

    $.add overlay, dialog
    $.add d.body, overlay
    
    # Open default tab
    links[0].click()

  close: ->
    return unless DHashMenu.overlay
    d.activeElement?.blur()
    $.rm DHashMenu.overlay
    delete DHashMenu.overlay
    delete DHashMenu.dialog

  openTab: (tab, dialog) ->
    # Update active tab styling
    if selected = $ '.tab-selected', dialog
      $.rmClass selected, 'tab-selected'
    $.addClass $(".tab-#{tab.title.toLowerCase()}", dialog), 'tab-selected'

    # Clean and Render section
    section = $ 'section', dialog
    $.rmAll section
    section.className = "section-#{tab.title.toLowerCase()}"
    section.scrollTop = 0
    
    tab.cb(section)

  main: (section) ->
    # Reuse Settings.coffee logic for checkboxes
    items  = $.dict()
    inputs = $.dict()
    
    addCheckboxes = (root, obj) ->
      containers = [root]
      for key, arr of obj when arr instanceof Array
        # Filter: Only show dHash relevant settings from Config.main
        # We know dHash settings are in 'Filtering', but let's just check the key name
        continue unless key.indexOf('dHash') > -1 or key is 'Image dHash'

        description = arr[1]
        div = $.el 'div',
           innerHTML: "<label><input type=\"checkbox\" name=\"#{key}\">#{key}</label><span class=\"description\">: #{description}</span>"
        
        div.dataset.name = key
        input = $ 'input', div
        $.on input, 'change', $.cb.checked
        $.on input, 'change', -> @parentNode.parentNode.dataset.checked = @checked
        
        items[key]  = Conf[key]
        inputs[key] = input
        
        level = arr[2] or 0
        if containers.length <= level
          container = $.el 'div', className: 'suboption-list'
          $.add containers[containers.length-1].lastElementChild, container
          containers[level] = container
        else if containers.length > level+1
          containers.splice level+1, containers.length - (level+1)
        $.add containers[level], div

    # Iterate through Config.main sections
    for keyFS, obj of Config.main
      # Check if this section has any dHash settings
      hasDHash = false
      for key of obj
        if key.indexOf('dHash') > -1 or key is 'Image dHash'
           hasDHash = true
           break
      
      continue unless hasDHash

      fs = $.el 'fieldset',
        innerHTML: "<legend>#{keyFS}</legend>"
      addCheckboxes fs, obj
      $.add section, fs
    
    # Sync initial values
    $.get items, (items) ->
      for key, val of items
        if inputs[key]
           inputs[key].checked = val
           inputs[key].parentNode.parentNode.dataset.checked = val
      return

  data: (section) ->
    div = $.el 'div',
      innerHTML: 'dHash Database (Format: dHash ### postID ### MD5)<br>'
    
    dbInput = $.el 'textarea',
      className: 'field'
      style: 'width: 100%; height: 400px; display: block;'
      placeholder: 'Database content will appear here...'
    
    # Bind to Conf
    dbInput.value = Conf['dhashDatabase'] or ''
    
    $.on dbInput, 'input', ->
      Conf['dhashDatabase'] = @value
      $.set 'dhashDatabase', @value
      
    $.add div, dbInput
    $.add section, div
