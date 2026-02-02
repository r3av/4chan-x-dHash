<% if (readJSON('/.tests_enabled')) { %>
Test =
  init: ->
    return unless g.SITE.software is 'yotsuba' and g.VIEW in ['index', 'thread']

    if Conf['Menu']
      a = $.el 'a',
        textContent: 'Test HTML building'
      $.on a, 'click', @cb.testOne
      Menu.menu.addEntry
        el: a
        open: (post) ->
          a.dataset.fullID = post.fullID
          true

    a2 = $.el 'a',
      textContent: 'Test HTML building'
    $.on a2, 'click', @cb.testAll
    Header.menu.addEntry
      el: a2

    if Unread.posts
      testOrderLink = $.el 'a',
        textContent: 'Test Post Order'
      $.on testOrderLink, 'click', @cb.testOrder
      Header.menu.addEntry
        el: testOrderLink

    $.on d, 'keydown', @cb.keydown

    if Conf['Image dHash']
       dhashLink = $.el 'a',
         textContent: 'Test dHash'
       $.on dhashLink, 'click', @dhash.run
       Header.menu.addEntry
         el: dhashLink

       gauntletLink = $.el 'a',
         textContent: 'Test dHash Gauntlet'
       $.on gauntletLink, 'click', @dhash.runGauntlet
       Header.menu.addEntry
         el: gauntletLink

  dhash:
    run: ->
      try
        c.log "Starting dHash tests..."
        Test.dhash.testHash 'Solid Black'
        Test.dhash.testHash 'Gradient'
        Test.dhash.testRobustness()
        Test.dhash.testSelected()
      catch err
        new Notice 'error', "dHash Test Error: #{err.message}", 20
        console.error err
      return

    runGauntlet: ->
       try
          postsWithImages = []
          g.posts.forEach (post) ->
             if post.file
                postsWithImages.push(post)
          
          total = postsWithImages.length
          if total is 0
             new Notice 'warning', "No images found in thread.", 5
             return

          new Notice 'info', "Starting Gauntlet on #{total} images...", 5
          console.log "%c[Gauntlet] Starting run on #{total} images...", "color: blue; font-weight: bold;"

          # Stats
          passed = 0
          failed = 0
          processed = 0
          
          # Helper to create modified canvas with white background
          createCanvas = (w, h) ->
             cv = $.el 'canvas', width: w, height: h
             ctx = cv.getContext '2d'
             ctx.fillStyle = '#FFFFFF'
             ctx.fillRect(0, 0, w, h)
             {canvas: cv, ctx: ctx}

          processNext = (index) ->
             if index >= total
                # Done
                msg = "[Gauntlet] Complete! Passed: #{passed}, Failed: #{failed}, Total: #{total}"
                console.log "%c#{msg}", "color: #{if failed is 0 then 'green' else 'red'}; font-weight: bold;"
                new Notice (if failed is 0 then 'success' else 'warning'), msg, 20
                return

             post = postsWithImages[index]
             processed++
             
             # Log progress every 10 images
             if processed % 10 is 0
                new Notice 'info', "Gauntlet: #{processed}/#{total}...", 2

             img = new Image()
             img.crossOrigin = 'Anonymous'
             img.src = post.file.url
             
             done = ->
                # Schedule next one
                setTimeout (-> processNext(index + 1)), 10

             img.onload = ->
                try
                   # 1. Base Hash
                   baseCtx = createCanvas(img.width, img.height)
                   baseCtx.ctx.drawImage(img, 0, 0)
                   baseHash = DHash.computeHash(baseCtx.canvas)

                   # 2. Thumbnail Sim (The core "robustness" check)
                   scale = Math.min(250/img.width, 250/img.height, 1)
                   tw = Math.floor(img.width * scale)
                   th = Math.floor(img.height * scale)
                   
                   thumbObj = createCanvas(tw, th)
                   thumbObj.ctx.drawImage(img, 0, 0, tw, th)
                   thumbHash = DHash.computeHash(thumbObj.canvas)
                   
                   dist = Filter.hammingDistance(baseHash, thumbHash)
                   
                   if dist <= 5
                      passed++
                      console.log "%c[PASS] #{post.ID}: Dist #{dist}", "color: green;"
                   else
                      failed++
                      console.log "%c[FAIL] #{post.ID}: Dist #{dist} (Full: #{baseHash}, Thumb: #{thumbHash})", "color: red; font-weight: bold;"
                      console.log post.file.url

                catch err
                   console.error "Error processing #{post.ID}", err
                finally
                   done()
             
             img.onerror = ->
                console.warn "Failed to load image for #{post.ID}"
                done()

          # Start
          processNext(0)
          
       catch err
          new Notice 'error', "Gauntlet Error: #{err.message}", 20
          console.error err

    testSelected: ->
      # Find selected post (native 4chan checkbox)
      selectedPost = null
      g.posts.forEach (post) ->
         if post.nodes.root.querySelector('input[type="checkbox"]:checked')
            selectedPost = post
      
      unless selectedPost
         new Notice 'info', "Select a post with an image to run Advanced Tests.", 5
         return

      unless selectedPost.file
         new Notice 'warning', "Selected post has no image.", 5
         return
      
      new Notice 'info', "Testing selected post: #{selectedPost.ID}", 3
      console.log "%cTesting Selected Post: #{selectedPost.ID} (#{selectedPost.file.url})", "font-weight: bold; color: blue;"

      # Load Image
      img = new Image()
      img.crossOrigin = 'Anonymous'
      img.src = selectedPost.file.url
      img.onload = ->
        try 
          console.log "Image Loaded: #{img.width}x#{img.height}"
          
          # Helper to create modified canvas with white background (handles transparent PNGs)
          createCanvas = (w, h) ->
             cv = $.el 'canvas', width: w, height: h
             ctx = cv.getContext '2d'
             ctx.fillStyle = '#FFFFFF'
             ctx.fillRect(0, 0, w, h)
             {canvas: cv, ctx: ctx}

          # 1. Base Hash (Full Image -> dHash)
          # We use our helper to ensure white background for the base too
          baseCtx = createCanvas(img.width, img.height)
          baseCtx.ctx.drawImage(img, 0, 0)
          baseHash = DHash.computeHash(baseCtx.canvas)
          console.log "%cOriginal Hash: #{baseHash}", "font-weight: bold;"
          
          # Helper to compute distance and report
          checkDiff = (name, hash) ->
             dist = Filter.hammingDistance(baseHash, hash)
             msg = "#{name}: Dist #{dist} (Hash: #{hash})"
             if dist <= 5
               new Notice 'success', "PASS: #{name} (Dist #{dist})", 5
               console.log "%cPASS: #{msg}", "color: green;"
             else
               new Notice 'warning', "FAIL: #{name} (Dist #{dist})", 20
               console.log "%cFAIL: #{msg}", "color: red;"

          # --- Variations ---
          
          # A. Thumbnail Simulation (Resize to max 250px dim)
          scale = Math.min(250/img.width, 250/img.height, 1)
          tw = Math.floor(img.width * scale)
          th = Math.floor(img.height * scale)
          
          thumbObj = createCanvas(tw, th)
          thumbObj.ctx.drawImage(img, 0, 0, tw, th)
          checkDiff 'Thumbnail Sim', DHash.computeHash(thumbObj.canvas)

          # B. Center Crop (90%)
          cw = Math.floor(img.width * 0.9)
          ch = Math.floor(img.height * 0.9)
          cx = Math.floor((img.width - cw) / 2)
          cy = Math.floor((img.height - ch) / 2)
          
          cropObj = createCanvas(cw, ch)
          cropObj.ctx.drawImage(img, cx, cy, cw, ch, 0, 0, cw, ch)
          
          cropHash = DHash.computeHash(cropObj.canvas)
          distCrop = Filter.hammingDistance(baseHash, cropHash)
          console.log "Center Crop 90%: Dist #{distCrop} (Hash: #{cropHash})"
          
          # dHash is not crop invariant. Expect failure on crops.
          if distCrop <= 5
             new Notice 'success', "PASS: Center Crop 90% (Dist #{distCrop})", 5
             console.log "%cPASS: Center Crop 90% (Dist #{distCrop})", "color: green;"
          else
             new Notice 'info', "INFO: Center Crop 90% Failed as expected (Dist #{distCrop})", 5
             console.log "%cINFO: Center Crop 90% Failed as expected (Dist #{distCrop})", "color: orange;"

          # C. Mirror (Horizontal Flip) - EXPECT FAIL
          mirrorObj = createCanvas(img.width, img.height)
          mirrorObj.ctx.translate(img.width, 0)
          mirrorObj.ctx.scale(-1, 1)
          mirrorObj.ctx.drawImage(img, 0, 0)
          
          mirrorHash = DHash.computeHash(mirrorObj.canvas)
          distMirror = Filter.hammingDistance(baseHash, mirrorHash)
          console.log "Mirror Dist: #{distMirror} (Hash: #{mirrorHash})"
          
          if distMirror > 5
             new Notice 'success', "PASS: Mirror should fail (Dist: #{distMirror})", 5
             console.log "%cPASS: Mirror should fail (Dist: #{distMirror})", "color: green;"
          else
             new Notice 'info', "INFO: Mirror matched? (Dist: #{distMirror})", 5
             console.log "%cINFO: Mirror matched? (Dist: #{distMirror})", "color: orange;"
          
          # D. JPEG Compression Sim (via toDataURL)
          # Note: Canvas toDataURL usually defaults to png unless specified.
          thumbUrl = thumbObj.canvas.toDataURL('image/jpeg', 0.5)
          lossyImg = new Image()
          lossyImg.onload = ->
             # Draw lossy image onto white canvas to be safe
             lossyObj = createCanvas(lossyImg.width, lossyImg.height)
             lossyObj.ctx.drawImage(lossyImg, 0, 0)
             checkDiff 'Heavy Compression', DHash.computeHash(lossyObj.canvas)
          lossyImg.src = thumbUrl
          
        catch err
           new Notice 'error', "Variation Error: #{err.message}", 20
           console.error err

      img.onerror = ->
         new Notice 'error', "Failed to load image (CORS?)", 20

    testHash: (name) ->
      try
        # Create a canvas and draw the test pattern directly
        # This bypasses Image loading and CSP issues with data URIs
        canvas = $.el 'canvas', width: 9, height: 8
        ctx = canvas.getContext '2d'
        
        if name is 'Solid Black'
          ctx.fillStyle = '#000000'
          ctx.fillRect(0, 0, 9, 8)
          expected = '0000000000000000'
        else if name is 'Gradient'
          # Create a gradient that is brighter on the left
          # dHash sets bit to 1 if Left pixel > Right pixel
          # So we want Left=Bright, Right=Dark
          for y in [0...8]
            for x in [0...9]
               val = 255 - (x * 25) # 255, 230, 205...
               ctx.fillStyle = "rgb(#{val},#{val},#{val})"
               ctx.fillRect(x, y, 1, 1)
          expected = 'ffffffffffffffff'

        hash = DHash.computeHash(canvas) # computeHash accepts canvas too (drawImage support)
        
        if hash is expected
          new Notice 'success', "PASS: #{name}", 5
          c.log "PASS: #{name} - #{hash}"
        else
          new Notice 'warning', "FAIL: #{name}. Exp: #{expected}, Got: #{hash}", 20
          c.log "FAIL: #{name}. Exp: #{expected}, Got: #{hash}"
      catch err
         new Notice 'error', "Test #{name} Error: #{err.message}", 20
         console.error err

    testRobustness: ->
      try
        c.log "Running Robustness Tests..."
        
        # Base Pattern: A checkered pattern
        baseCanvas = $.el 'canvas', width: 100, height: 100
        ctx = baseCanvas.getContext '2d'
        ctx.fillStyle = '#FFFFFF'
        ctx.fillRect(0,0,100,100)
        ctx.fillStyle = '#000000'
        ctx.fillRect(0,0,50,50)
        ctx.fillRect(50,50,50,50)
        
        baseHash = DHash.computeHash(baseCanvas)
        c.log "Base Hash: #{baseHash}"

        # 1. Shift Test (Slight translation)
        shiftCanvas = $.el 'canvas', width: 100, height: 100
        sCtx = shiftCanvas.getContext '2d'
        sCtx.drawImage(baseCanvas, 1, 1) # Shift by 1px
        shiftHash = DHash.computeHash(shiftCanvas)
        
        distShift = Filter.hammingDistance(baseHash, shiftHash)
        if distShift <= 5
          new Notice 'success', "PASS: Shift Test (Dist: #{distShift})", 5
        else
           new Notice 'warning', "FAIL: Shift Test (Dist: #{distShift})", 20

        # 2. Crop Test (95% scale)
        cropCanvas = $.el 'canvas', width: 100, height: 100
        cCtx = cropCanvas.getContext '2d'
        cCtx.drawImage(baseCanvas, 0, 0, 95, 95, 0, 0, 100, 100) # Draw 95x95 region into 100x100
        cropHash = DHash.computeHash(cropCanvas)

        distCrop = Filter.hammingDistance(baseHash, cropHash)
        if distCrop <= 5
          new Notice 'success', "PASS: Crop Test (Dist: #{distCrop})", 5
        else
           new Notice 'warning', "FAIL: Crop Test (Dist: #{distCrop})", 20
      catch err
         new Notice 'error', "Robustness Test Error: #{err.message}", 20
         console.error err


  assert: (condition) ->
    unless condition()
      new Notice 'warning', "Assertion failed: #{condition}", 30

  normalize: (root) ->
    root2 = root.cloneNode true
    for el in $$ '.mobile', root2
      $.rm el
    for el in $$ 'a[href]', root2
      href = el.href
      href = href.replace /(^\w+:\/\/boards\.4chan(?:nel)?\.org\/[^\/]+\/thread\/\d+)\/.*/, '$1'
      el.setAttribute 'href', href
    ImageHost.fixLinks $$('.fileText > a, a.fileThumb', root2)
    for el in $$ 'img[src]', root2
      el.src = el.src.replace /(spoiler-\w+)\d(\.png)$/, '$11$2'
    for el in $$ 'pre.prettyprinted', root2
      nodes = $.X './/br|.//wbr|.//text()', el
      i = 0
      nodes = (node while (node = nodes.snapshotItem i++))
      $.rmAll el
      $.add el, nodes
      el.normalize()
      $.rmClass el, 'prettyprinted'
    for el in $$ 'pre[style=""]', root2
      el.removeAttribute 'style'
    # XXX https://bugzilla.mozilla.org/show_bug.cgi?id=1021289
    $('.fileInfo[data-md5]', root2)?.removeAttribute 'data-md5'
    textNodes = $.X './/text()', root2
    i = 0
    while (node = textNodes.snapshotItem i++)
      node.data = node.data.replace /\ +/g, ' '
      # XXX https://a.4cdn.org/sci/thread/5942502.json, https://a.4cdn.org/news/thread/6.json, https://a.4cdn.org/wsg/thread/957536.json
      node.data = node.data.replace /^\n+/g, '' if node.previousSibling?.nodeName is 'BR'
      node.data = node.data.replace /\n+$/g, '' if node.nextSibling?.nodeName is 'BR'
      $.rm node if node.data is ''
    root2

  firstDiff: (x, y) ->
    x2 = x.cloneNode false
    y2 = y.cloneNode false
    return [x2, y2] unless x2.isEqualNode y2
    i = 0
    while true
      x2 = x.childNodes[i]
      y2 = y.childNodes[i]
      return [x2, y2] unless x2 and y2
      return Test.firstDiff(x2, y2) unless x2.isEqualNode y2
      i++

  testOne: (post) ->
    Test.postsRemaining++
    $.cache g.SITE.urls.threadJSON({boardID: post.boardID, threadID: post.threadID}), ->
      return unless @response
      {posts} = @response
      g.SITE.Build.spoilerRange[post.board.ID] = posts[0].custom_spoiler
      for postData in posts
        if postData.no is post.ID
          t1 = new Date().getTime()
          obj = g.SITE.Build.parseJSON postData, post.board
          root = g.SITE.Build.post obj
          t2 = new Date().getTime()
          Test.time += t2 - t1
          post2 = new Post root, post.thread, post.board, {forBuildTest: true}
          fail = false

          x = post.normalizedOriginal
          y = post2.normalizedOriginal
          unless x.isEqualNode y
            fail = true
            c.log "#{post.fullID} differs"
            [x2, y2] = Test.firstDiff x, y
            c.log x2
            c.log y2
            c.log x.outerHTML
            c.log y.outerHTML

          for key of Config.filter when not key is 'General' and not (key is 'MD5' and post.board.ID is 'f')
            val1 = Filter.values key, obj
            val2 = Filter.values key, post2
            unless val1.length is val2.length and val1.every((x, i) -> x is val2[i])
              fail = true
              c.log "#{post.fullID} has filter bug in #{key}"
              c.log val1
              c.log val2

          if fail
            Test.postsFailed++
          else
            c.log "#{post.fullID} correct"
          Test.postsRemaining--
          Test.report() if Test.postsRemaining is 0
      return

  testAll: ->
    g.posts.forEach (post) ->
      unless post.isClone or post.isFetchedQuote
        if not ((abbr = $ '.abbr', post.nodes.comment) and /Comment too long\./.test(abbr.textContent))
          Test.testOne post
    return

  postsRemaining: 0
  postsFailed: 0
  time: 0

  report: ->
    if Test.postsFailed
      new Notice 'warning', "#{Test.postsFailed} post(s) differ (#{Test.time} ms)", 30
    else
      new Notice 'success', "All correct (#{Test.time} ms)", 5
    Test.postsFailed = Test.time = 0

  cb:
    testOne: ->
      Test.testOne g.posts.get(@dataset.fullID)
      Menu.menu.close()

    testAll: ->
      Test.testAll()
      Header.menu.close()

    testOrder: ->
      list1 = (x.ID for x in Unread.order.order())
      list2 = (+x.id.match(/\d*$/)[0] for x in $$ (if g.SITE.isOPContainerThread then "#{g.SITE.selectors.thread}, " else '') + g.SITE.selectors.postContainer)
      pass = do ->
        return false unless list1.length is list2.length
        for i in [0...list1.length] by 1
          return false if list1[i] isnt list2[i]
        true
      if pass
        new Notice 'success', "Orders same (#{list1.length} posts)", 5
      else
        new Notice 'warning', 'Orders differ.', 30
        c.log list1
        c.log list2

    keydown: (e) ->
      return unless Keybinds.keyCode(e) is 'v'
      return if e.target.nodeName in ['INPUT', 'TEXTAREA']
      Test.testAll()
      e.preventDefault()
      e.stopPropagation()
<% } %>
