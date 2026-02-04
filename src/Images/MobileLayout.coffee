MobileLayout =
  init: ->
    Callbacks.Post.push
      name: 'Mobile Image Info'
      cb:   @node

  node: ->
    return unless @file
    # Guard against duplicate execution
    return if $('.mFileInfo.mobile', @file.text.parentNode)

    
    # Create info element matching native style: "1.11 MB JPG"
    infoContent = "#{@file.size} #{@file.tag or 'JPG'}"
    divInfo = $.el 'div',
      className: 'mFileInfo mobile'
      textContent: infoContent
    
    # Create filename element: "filename.jpg"
    divName = $.el 'div',
      className: 'mFilename mobile'
      textContent: @file.name

    # Set tips per user expectation (though native app behavior might differ, we follow request)
    divInfo.setAttribute 'data-tip', ''
    divInfo.setAttribute 'data-tip-cb', 'mShowFull'

    if @file.thumbLink
      $.after @file.thumbLink, divInfo
      $.after @file.thumbLink, divName 
    return
