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

    if Conf['Save Thread Data'] or 
       Conf['Save dHash Filtered Post Data'] or
       Conf['Save MD5 Filtered Post Data'] or
       Conf['Save Name Filtered Post Data'] or
       Conf['Save Tripcode Filtered Post Data'] or
       Conf['Save Comment Filtered Post Data'] or
       Conf['Save Filename Filtered Post Data']
      try
        DHash.postData = JSON.parse(Conf['dhash_post_data'] or '{}')
      catch
        DHash.postData = {}

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
    return unless Conf['Image dHash'] and e.detail
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
      {hide, stub, match} = Filter.test post
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

        # Capture the trigger and check if we should save
        if match
          triggered = false
          reason = ''
          if match.key is 'dhash'
            if Conf['Save dHash Filtered Post Data']
              triggered = true
              reason = if match.distance is 0 then 'dhash matched existing dhash' else "dhash matched close to existing dhash <#{match.distance}>"
          else if match.key is 'MD5'
            if Conf['Save MD5 Filtered Post Data']
              triggered = true
              reason = 'from existing md5'
          else if match.key is 'name' and Conf['Save Name Filtered Post Data']
            triggered = true
          else if match.key is 'tripcode' and Conf['Save Tripcode Filtered Post Data']
            triggered = true
          else if match.key is 'comment' and Conf['Save Comment Filtered Post Data']
            triggered = true
          else if match.key is 'filename' and Conf['Save Filename Filtered Post Data']
            triggered = true
          else if Conf["Save #{match.key[0].toUpperCase() + match.key[1..]} Filtered Post Data"] # Fallback for others
            triggered = true

          if triggered and file.dhash
            reason or= "filtered by #{match.key}"
            DHash.collect post, file, reason

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
    else
       DHash.saveData()

  saveData: ->
    return unless (Conf['Save Thread Data'] or 
       Conf['Save dHash Filtered Post Data'] or
       Conf['Save MD5 Filtered Post Data'] or
       Conf['Save Name Filtered Post Data'] or
       Conf['Save Tripcode Filtered Post Data'] or
       Conf['Save Comment Filtered Post Data'] or
       Conf['Save Filename Filtered Post Data']) and DHash.dataChanged
    
    # Persist the collected data
    json = JSON.stringify(DHash.postData, null, 2)
    Conf['dhash_post_data'] = json
    $.set 'dhash_post_data', json
    DHash.dataChanged = false
    
  collect: (post, file, reason) ->
    return unless Conf['Save Thread Data'] or 
       Conf['Save dHash Filtered Post Data'] or
       Conf['Save MD5 Filtered Post Data'] or
       Conf['Save Name Filtered Post Data'] or
       Conf['Save Tripcode Filtered Post Data'] or
       Conf['Save Comment Filtered Post Data'] or
       Conf['Save Filename Filtered Post Data']
    
    entry =
      board:     post.board.ID
      num:       post.ID
      filehash:  post.file.MD5
      filename:  post.file.name
      timestamp: Math.floor(post.info.date.getTime() / 1000)
      name:      post.info.name or "Anonymous"
      text:      post.info.comment or null
      trip:      post.info.tripcode or null
      preview_w: file.thumb?.naturalWidth or file.thumb?.width or null
      preview_h: file.thumb?.naturalHeight or file.thumb?.height or null
      media_w:   file.width or (if file.dimensions then +file.dimensions.split('x')[0] else null)
      media_h:   file.height or (if file.dimensions then +file.dimensions.split('x')[1] else null)
      reason_added: reason or 'thread-wide'
      
    hash = file.dhash
    DHash.postData[hash] or= []
    
    # Avoid duplicates and handle reason priority
    # Manual > Exact dHash > Close dHash > MD5 > Other Filter > Thread-wide
    getPriority = (r) ->
      return 100 if r is 'manual'
      return 90 if r is 'dhash matched existing dhash'
      return 80 if r?.startsWith 'dhash matched close'
      return 70 if r is 'from existing md5'
      return 60 if r?.startsWith 'filtered by'
      return 10
      
    exists = false
    priority = getPriority entry.reason_added
    for item in DHash.postData[hash]
      if item.board is entry.board and item.num is entry.num
         exists = true
         if getPriority(item.reason_added) < priority
            item.reason_added = entry.reason_added
            DHash.dataChanged = true
         break
         
    unless exists
       DHash.postData[hash].push entry
       DHash.dataChanged = true

  compute: ({post, file, img}) ->
    return unless img.naturalWidth # sanity check
    
    try
      file.dhash = DHash.computeHash(img)
      if file.MD5
         DHash.md5Cache[file.MD5] = file.dhash
      if Conf['Save Thread Data']
        DHash.collect post, file, 'thread-wide'
      DHash.check post, file
    catch err
      # console.error 'dHash error', err
    
    DHash.processed++
    DHash.updateStatus()

  computeHash: (img) ->
    c = $.el 'canvas', width: 9, height: 8
    ctx = c.getContext '2d'
    
    # Pre-scale large images to reduce aliasing artifacts.
    # We normalize to match standard thumbnail geometry (~250px max dimension).
    # This ensures that hashing a full image yields similar results to hashing its thumbnail.
    maxDim = 250
    if img.width > maxDim or img.height > maxDim
       scale = Math.min(maxDim / img.width, maxDim / img.height)
       w = Math.floor(img.width * scale)
       h = Math.floor(img.height * scale)
       
       # Create intermediate canvas
       cv = document.createElement 'canvas'
       cv.width = w
       cv.height = h
       ct = cv.getContext '2d'
       ct.drawImage img, 0, 0, w, h
       img = cv

    # Draw final result into the 9x8 grid
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
