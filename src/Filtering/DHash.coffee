DHash =
  queue: []
  processing: false
  processed: 0
  total: 0
  filteredCount: 0
  newMD5Count: 0

  init: ->
    return unless Conf['Filter']

    if Conf['Show dHash Status'] or Conf['Show dHash Calculation Progress']
      @status = $.el 'span',
        className: 'brackets-wrap shortcut'
        title: 'dHash Image Filtering'
      DHash.updateStatus()
      $.ready -> Header.addShortcut 'dhash', DHash.status, 500
      
      $.sync 'Image dHash', DHash.updateStatus
      $.sync 'Show dHash Status', DHash.updateStatus
      $.sync 'Show dHash Calculation Progress', DHash.updateStatus
      $.sync 'dHash Stats', DHash.updateStatus

    Callbacks.Post.push
      name: 'DHash'
      cb:   @node

    $.on d, 'PostsInserted', DHash.onPostsInserted

  updateStatus: ->
    return unless DHash.status
    
    parts = []
    
    # Status / Progress
    if !Conf['Image dHash']
      parts.push "dHash: Off"
    else if Conf['Show dHash Calculation Progress'] and DHash.total > DHash.processed
      parts.push "dHash: #{DHash.processed}/#{DHash.total}"
    else if Conf['Show dHash Status']
      parts.push "dHash: On"
      
    # Stats
    if Conf['Image dHash'] and Conf['dHash Stats']
      stats = []
      if DHash.filteredCount > 0
         stats.push "Filtered: #{DHash.filteredCount}"
      if DHash.newMD5Count > 0
         stats.push "New MD5s: #{DHash.newMD5Count}"
      
      if stats.length
         parts.push stats.join(', ')

    text = parts.join(' | ')
    if text
       DHash.status.textContent = text
       DHash.status.hidden = false
    else
       DHash.status.hidden = true

  node: ->
    return if @isClone or !Conf['Image dHash']
    for file in @files
      if file.thumb
        DHash.prepare @, file

  onPostsInserted: (e) ->
    return unless Conf['Image dHash']
    for post in e.detail
      continue if post.isClone
      for file in post.files
        if file.thumb and !file.dhash
          DHash.prepare post, file

  md5Cache: $.dict()

  prepare: (post, file) ->
    img = file.thumb
    return unless img
    
    # Check cache first
    if file.MD5 and (cachedHash = DHash.md5Cache[file.MD5])
       file.dhash = cachedHash
       DHash.check post, file
       return

    DHash.total++
    DHash.updateStatus()
    
    startTime = Date.now()

    calc = ->
      loadTime = Date.now() - startTime
      DHash.queue.push {post, file, img}
      DHash.run()
    
    # Eagerly prepare the image for reading
    if Conf['Hide until dHash']
       $.addClass post.nodes.root, 'dhash-pending'

    if img.complete and img.naturalWidth
       if img.crossOrigin isnt 'anonymous' and !/^data:/.test(img.src)
          img.crossOrigin = 'anonymous'
          img.onload = calc
          img.onerror = -> 
             # On error, we just skip it but count it as processed
             DHash.processed++
             DHash.updateStatus()
          img.src = img.src # Trigger reload with new crossOrigin
       else
          calc()
    else
       img.crossOrigin = 'anonymous'
       img.onload = calc
       img.onerror = ->
          DHash.processed++
          DHash.updateStatus()

  check: (post, file) ->
    if Conf['Hide until dHash']
       $.rmClass post.nodes.root, 'dhash-pending'

    try
      {hide, stub} = Filter.test post
      if hide
        DHash.filteredCount++
        DHash.updateStatus()

        if Conf['Save dHash MD5s'] and file.MD5
          # Check if this MD5 is already filtered to avoid duplicate entries
          alreadyFiltered = false
          if Filter.filters.MD5
            for filter in Filter.filters.MD5
              if filter.regexp is file.MD5
                alreadyFiltered = true
                break
          
          unless alreadyFiltered
            Filter.addFilter 'MD5', "/#{file.MD5}/"
            DHash.newMD5Count++
            DHash.updateStatus()

        if post.isReply
          PostHiding.hide post, stub
        else
          ThreadHiding.hide post.thread, stub
    catch err
      # console.error 'dHash error', err

  run: ->
    return if DHash.processing or !DHash.queue.length
    DHash.processing = true
    
    task = DHash.queue.shift()
    DHash.compute task
    
    DHash.processing = false
    
    if DHash.queue.length
       if window.requestIdleCallback
          window.requestIdleCallback DHash.run, { timeout: 100 }
       else
          setTimeout DHash.run, 0

  compute: ({post, file, img}) ->
    return unless img.naturalWidth # sanity check
    
    try
      file.dhash = DHash.computeHash(img)
      if file.MD5
         DHash.md5Cache[file.MD5] = file.dhash
      DHash.check post, file
    catch err
      # console.error 'dHash error', err
    
    DHash.processed++
    DHash.updateStatus()

  computeHash: (img) ->
    c = $.el 'canvas', width: 9, height: 8
    ctx = c.getContext '2d'
    ctx.drawImage img, 0, 0, 9, 8
    data = ctx.getImageData(0, 0, 9, 8).data
    
    hash = ''
    hashIndex = 0
    currentInt = 0
    
    for y in [0...8]
      for x in [0...8]
        offset = (y * 9 + x) * 4
        px1 = (data[offset] + data[offset+1] + data[offset+2]) / 3
        px2 = (data[offset+4] + data[offset+5] + data[offset+6]) / 3
        
        if px1 > px2
          currentInt |= (1 << hashIndex)
          
        hashIndex++
        if hashIndex is 4
           hash += currentInt.toString(16)
           currentInt = 0
           hashIndex = 0

    return hash
