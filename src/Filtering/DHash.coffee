DHash =
  queue: []
  processing: false
  processed: 0
  total: 0
  filteredCount: 0
  newMD5Count: 0
  forceAdd: false
  dataChanged: false

  init: ->
    return unless Conf['Filter']
    $.on window, 'beforeunload', DHash.saveData


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

    # Check if already processing/processed (avoids duplicate queueing)
    return if file.dhashIsProcessing
    file.dhashIsProcessing = true
    
    DHash.total++
    DHash.updateStatus()
    
    startTime = Date.now()

    calc = (sourceImg) ->
      DHash.queue.push {post, file, img: sourceImg}
      DHash.run()
    
    # Handle image loading using a detached Image object to ensure it loads even if hidden
    # Use the thumbnail URL
    url = img.src
    # Handle data-src if lazy loaded? 4chan X usually sets src.
    
    dummy = new Image()
    dummy.crossOrigin = 'anonymous'
    
    dummy.onload = ->
      calc(dummy)
      
    dummy.onerror = ->
      DHash.processed++
      DHash.updateStatus()
      
    dummy.src = url
    
    # Eagerly prepare the DOM element too just in case visuals need it
    if Conf['Hide until dHash']
       $.addClass post.nodes.root, 'dhash-pending'

  check: (post, file) ->
    if Conf['Hide until dHash']
       $.rmClass post.nodes.root, 'dhash-pending'

    try
      {hide, stub, match, matches} = Filter.test post
      if hide
        DHash.filteredCount++
        DHash.updateStatus()

        if Conf['Save dHash MD5s'] and file.MD5 and match and match.key is 'dhash'
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
        triggers = matches
        unless triggers
          if match
            triggers = [match]
          else
            triggers = []

        if triggers.length > 0
          triggered = false
          reason = ''
          
          for m in triggers
            continue unless m
            r = ''
            t = false
            key = m.key
            
            if key is 'dhash' and Conf['Save dHash Filtered Post Data']
              r = if m.distance is 0 then 'dhash matched existing dhash' else "dhash matched close to existing dhash <#{m.distance}>"
              t = true
            else if key is 'MD5' and Conf['Save MD5 Filtered Post Data']
              r = 'from existing md5'
              t = true
            else if key is 'name' and Conf['Save Name Filtered Post Data']
              r = 'filtered by name'
              t = true
            else if key is 'tripcode' and Conf['Save Tripcode Filtered Post Data']
              r = 'filtered by tripcode'
              t = true
            else if key is 'comment' and Conf['Save Comment Filtered Post Data']
              r = 'filtered by comment'
              t = true
            else if key is 'filename' and Conf['Save Filename Filtered Post Data']
              r = 'filtered by filename'
              t = true
            else if Conf["Save #{key[0].toUpperCase() + key[1..]} Filtered Post Data"]
              r = "filtered by #{key}"
              t = true
            
            if t
              triggered = true
              # Priority: dHash > MD5 > others
              if key is 'dhash'
                reason = r
                break
              if key is 'MD5'
                reason = r
              unless reason
                reason = r

          if triggered and file.dhash
            k = 'unknown'
            if triggers[0]
              k = triggers[0].key
            reason or= "filtered by #{k}"
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
    for item, idx in DHash.postData[hash]
      if item.board is entry.board and item.num is entry.num
         exists = true
         if DHash.forceAdd
            # Overwrite the entire entry, preserving reason if higher priority
            if getPriority(item.reason_added) >= priority
               entry.reason_added = item.reason_added
            DHash.postData[hash][idx] = entry
            DHash.dataChanged = true
         else if getPriority(item.reason_added) < priority
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
