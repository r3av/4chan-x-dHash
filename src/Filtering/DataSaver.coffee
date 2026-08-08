DataSaver =
  postData: {}
  dataChanged: false
  forceAdd: false
  saveTimer: null

  init: ->
    try
      DataSaver.postData = JSON.parse(Conf['dhash_post_data'] or '{}')
    catch
      DataSaver.postData = {}
      
    $.on window, 'beforeunload', DataSaver.saveData

  saveData: ->
    return unless (Conf['Save Thread Data'] or 
       Conf['Save dHash Filtered Post Data'] or
       Conf['Save MD5 Filtered Post Data'] or
       Conf['Save Name Filtered Post Data'] or
       Conf['Save Tripcode Filtered Post Data'] or
       Conf['Save Comment Filtered Post Data'] or
       Conf['Save Filename Filtered Post Data']) and DataSaver.dataChanged
    
    # Persist the collected data
    json = JSON.stringify(DataSaver.postData)
    Conf['dhash_post_data'] = json
    $.set 'dhash_post_data', json
    DataSaver.dataChanged = false

  scheduleSave: ->
    clearTimeout DataSaver.saveTimer if DataSaver.saveTimer
    DataSaver.saveTimer = setTimeout DataSaver.saveData, 5000
    
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
      thread_num: post.thread.ID
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
    # We use dHash as the primary key for clustering.
    return unless hash 
    
    DataSaver.postData[hash] or= []
    
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
    for item, idx in DataSaver.postData[hash]
      if item.board is entry.board and item.num is entry.num
         exists = true
         if DataSaver.forceAdd
            # Overwrite the entire entry, preserving reason if higher priority
            if getPriority(item.reason_added) >= priority
               entry.reason_added = item.reason_added
            DataSaver.postData[hash][idx] = entry
            DataSaver.dataChanged = true
         else if getPriority(item.reason_added) < priority
            item.reason_added = entry.reason_added
            DataSaver.dataChanged = true
         break
         
    unless exists
       DataSaver.postData[hash].push entry
       DataSaver.dataChanged = true
