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

       dhashMenuLink = $.el 'a',
         textContent: 'dHash Menu'
       $.on dhashMenuLink, 'click', ->
          console.log "dHash Menu clicked"
          console.log "DHashMenu type:", typeof DHashMenu
          if DHashMenu?
             DHashMenu.open()
          else
             console.error "DHashMenu is undefined!"
       Header.menu.addEntry
         el: dhashMenuLink

       # Database Writer Test
       dbWriteLink = $.el 'a',
          textContent: 'Test Database Write'
       $.on dbWriteLink, 'click', @dhash.writeDatabase
       Header.menu.addEntry
          el: dbWriteLink

       # Database Simulation Writer
       dbSimLink = $.el 'a',
          textContent: 'Simulate Image Dupes Database Write'
       $.on dbSimLink, 'click', @dhash.writeSimulatedDatabase
       Header.menu.addEntry
          el: dbSimLink

  dhash:
    writeDatabase: ->
      return unless Conf['Image dHash']
      
      console.log "Starting Database Write (JSON)..."

      # Load existing DB
      db = {}
      try
        currentVal = Conf['dhashDatabase']
        if currentVal and currentVal.trim()
           db = JSON.parse(currentVal)
      catch err
        console.error "Failed to parse existing dHash database:", err
        # Fallback to empty object if parse fails, essentially resetting or starting fresh
        db = {}

      count = 0
      
      g.posts.forEach (post) ->
        return unless post.file
        
        dhash = post.file.dhash
        
        # If not already calculated, try to calculate from thumb if available
        if !dhash and post.file.thumb and post.file.thumb.src and post.file.thumb.complete and post.file.thumb.naturalWidth
           try
             dhash = DHash.computeHash(post.file.thumb)
           catch err
             # console.error "Error hashing post #{post.ID}:", err
        
        if dhash
           # Structure: dHash > [ { board, num, md5, timestamp, name, trip } ]
           entry = 
             board:     post.board.ID
             num:       post.ID
             md5:       post.file.MD5
             timestamp: post.info.date
             name:      post.info.name or "Anonymous"
             trip:      post.info.tripcode or null

           # Initialize array for this hash if needed
           db[dhash] or= []
           
           # Check for duplicates (same board AND same num)
           exists = false
           for item in db[dhash]
             if item.board is entry.board and item.num is entry.num
                exists = true
                break
           
           unless exists
             db[dhash].push entry
             count++
      
      if count > 0
         # Save back as pretty-printed JSON
         newDB = JSON.stringify(db, null, 2)
         
         Conf['dhashDatabase'] = newDB
         $.set 'dhashDatabase', newDB
         
         new Notice 'success', "Added #{count} entries to dHash JSON Database", 3
         console.log "Added #{count} entries."
      else
         new Notice 'warning', "No new hashes found to add.", 3

    writeSimulatedDatabase: ->
       return unless Conf['Image dHash']
       
       console.log "Starting Simulated Database Write..."
       
       # Dynamic Loader
       loadLibs = (cb) ->
          loaded = 0
          check = -> 
             loaded++
             console.log "Library loaded. Count: #{loaded}"
             if loaded is 2 then cb()
          
          if window.JSZip
             console.log "JSZip already present"
             check()
          else
             new Notice 'info', "Loading JSZip...", 2
             script = $.el 'script',
                src: 'https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js'
                onload: check
                onerror: -> 
                   console.error "Failed to load JSZip"
                   new Notice 'error', "Failed to load JSZip", 5
             document.head.appendChild script
          
          if window.SparkMD5
             console.log "SparkMD5 already present"
             check()
          else
             new Notice 'info', "Loading SparkMD5...", 2
             script = $.el 'script',
                src: 'https://cdnjs.cloudflare.com/ajax/libs/spark-md5/3.0.2/spark-md5.min.js'
                onload: check
                onerror: -> 
                   console.error "Failed to load SparkMD5"
                   new Notice 'error', "Failed to load SparkMD5", 5
             document.head.appendChild script

       loadLibs ->
         console.log "Libraries loaded, starting processing..."
         # Load existing DB
         db = {}
         try
           currentVal = Conf['dhashDatabase']
           if currentVal and currentVal.trim()
               db = JSON.parse(currentVal)
         catch err
           console.error "Failed to parse existing DB:", err
           db = {}

         zip = new JSZip()
         simFolder = zip.folder("simulated")
         
         count = 0
         ids_processed = 0
         
         # Helper: Compute MD5 of a Blob/ArrayBuffer
         hashBlob = (blob, cb) ->
            reader = new FileReader()
            reader.onload = ->
               hex = SparkMD5.ArrayBuffer.hash(reader.result)
               # Convert Hex to Base64
               str = ""
               for i in [0...hex.length] by 2
                  str += String.fromCharCode(parseInt(hex.substr(i, 2), 16))
               base64 = btoa(str)
               cb(base64)
            reader.readAsArrayBuffer(blob)

         # Helper: Fetch URL as Blob
         fetchBlob = (url, cb) ->
            console.log "Fetching blob: #{url}"
            xhr = new XMLHttpRequest()
            xhr.open 'GET', url, true
            xhr.responseType = 'blob'
            xhr.onload = ->
               if xhr.status is 200
                  console.log "Fetched #{url} success"
                  cb(xhr.response)
               else
                  console.error "Fetched #{url} failed status: #{xhr.status}"
                  cb(null)
            xhr.onerror = -> 
               console.error "Fetched #{url} error"
               cb(null)
            xhr.send()

         processPost = (post, callback) ->
            unless post.file
               callback()
               return

            # We need the image for Canvas ops (Sims) AND the raw blob for Original
            img = new Image()
            img.crossOrigin = 'Anonymous'
            img.src = post.file.url
            
            img.onload = ->
               try
                  # Canvas Helper
                  createCanvas = (w, h) ->
                     cv = $.el 'canvas', width: w, height: h
                     ctx = cv.getContext '2d'
                     ctx.fillStyle = '#FFFFFF'
                     ctx.fillRect(0, 0, w, h)
                     {canvas: cv, ctx: ctx}

                  # Generic Entry Adder
                  addEntry = (type, hash, md5, blob, filename) ->
                     # Determine ID
                     idVal = if type is 'original' then post.ID else "#{post.ID}_sim_#{type}"
                     
                     entry = 
                       board:     post.board.ID
                       num:       idVal
                       md5:       md5
                       timestamp: Math.floor(post.info.date.getTime() / 1000)
                       name:      post.info.name or "Anonymous"
                       trip:      post.info.tripcode or null

                     db[hash] or= []
                     
                     # Check exists
                     exists = false
                     for item in db[hash]
                        if item.board is entry.board and item.num is entry.num
                           exists = true
                           break
                     
                     unless exists
                        db[hash].push entry
                        count++
                     
                     # Add to ZIP
                     if blob and filename
                        simFolder.file(filename, blob)

                  # Queue of operations for this post
                  ops = []

                  # 1. Original Image (Fetch Blob)
                  ops.push (nextOp) ->
                     fetchBlob post.file.url, (blob) ->
                        if blob
                           # Get correct extension
                           ext = post.file.url.split('.').pop()
                           # We still compute dHash (simulated canvas)
                           origObj = createCanvas(img.width, img.height)
                           origObj.ctx.drawImage(img, 0, 0)
                           origHash = DHash.computeHash(origObj.canvas)
                           addEntry 'original', origHash, post.file.MD5, blob, "#{post.ID}_original.#{ext}"
                        nextOp()

                  # 2. Original Thumb (Fetch Blob)
                  ops.push (nextOp) ->
                     if post.file.thumb
                        thumbUrlRaw = post.file.thumb.src
                        console.log "Fetching Thumb: #{thumbUrlRaw}"
                        fetchBlob thumbUrlRaw, (blob) ->
                           if blob
                              hashBlob blob, (md5) ->
                                 # We need dHash of thumb.
                                 thumbImg = new Image()
                                 # FIX: Use ObjectURL to avoid Tainted Canvas
                                 thumbUrl = URL.createObjectURL(blob)
                                 
                                 thumbImg.onload = ->
                                    try
                                       tObj = createCanvas(thumbImg.width, thumbImg.height)
                                       tObj.ctx.drawImage(thumbImg, 0, 0)
                                       tHash = DHash.computeHash(tObj.canvas)
                                       tExt = thumbUrlRaw.split('.').pop()
                                       addEntry 'original_thumb', tHash, md5, blob, "#{post.ID}_original_thumb.#{tExt}"
                                    catch err
                                       console.error "Thumb Sim Error:", err
                                    
                                    URL.revokeObjectURL(thumbUrl)
                                    nextOp()
                                 
                                 thumbImg.onerror = -> 
                                    URL.revokeObjectURL(thumbUrl)
                                    nextOp()
                                 
                                 thumbImg.src = thumbUrl # Use the local Blob URL
                           else nextOp()
                     else nextOp()

                  # Helper for Canvas Sims (Canvas -> Blob -> MD5 -> dHash -> Add)
                  runSim = (name, canvas, quality, nextOp) ->
                     canvas.toBlob ((blob) ->
                        hashBlob blob, (md5) ->
                           dhash = DHash.computeHash(canvas)
                           addEntry name, dhash, md5, blob, "#{post.ID}_sim_#{name}.jpg"
                           nextOp()
                     ), 'image/jpeg', quality

                  # 3. Sim Thumb (Resized to max 250)
                  ops.push (nextOp) ->
                     scale = Math.min(250/img.width, 250/img.height, 1)
                     tw = Math.floor(img.width * scale)
                     th = Math.floor(img.height * scale)
                     obj = createCanvas(tw, th)
                     obj.ctx.drawImage(img, 0, 0, tw, th)
                     runSim 'thumb', obj.canvas, 0.8, nextOp

                  # 4. Sim Crop 90%
                  ops.push (nextOp) ->
                     cw = Math.floor(img.width * 0.9)
                     ch = Math.floor(img.height * 0.9)
                     cx = Math.floor((img.width - cw) / 2)
                     cy = Math.floor((img.height - ch) / 2)
                     obj = createCanvas(cw, ch)
                     obj.ctx.drawImage(img, cx, cy, cw, ch, 0, 0, cw, ch)
                     runSim 'crop90', obj.canvas, 0.9, nextOp

                  # 5. Sim JPEG 50%
                  ops.push (nextOp) ->
                     # Create base thumb first
                     scale = Math.min(250/img.width, 250/img.height, 1)
                     tw = Math.floor(img.width * scale)
                     th = Math.floor(img.height * scale)
                     base = createCanvas(tw, th)
                     base.ctx.drawImage(img, 0, 0, tw, th)
                     
                     # Export low quality URL -> Load Image -> Draw -> Blob
                     lUrl = base.canvas.toDataURL('image/jpeg', 0.5)
                     lImg = new Image()
                     lImg.onload = ->
                        lObj = createCanvas(lImg.width, lImg.height)
                        lObj.ctx.drawImage(lImg, 0, 0)
                        runSim 'jpeg50', lObj.canvas, 0.9, nextOp # Save result as high q
                     lImg.src = lUrl

                  # 6. Sim Shift (1px)
                  ops.push (nextOp) ->
                     obj = createCanvas(img.width, img.height)
                     obj.ctx.fillStyle = '#FFFFFF'
                     obj.ctx.fillRect(0,0,img.width,img.height)
                     # Shift right 1px, down 1px
                     obj.ctx.drawImage(img, 1, 1) 
                     runSim 'shift', obj.canvas, 0.9, nextOp

                  # Run Ops
                  runOps = ->
                     if ops.length
                        op = ops.shift()
                        op(runOps)
                     else
                        callback()
                  runOps()

               catch err
                  console.error "Error simulating #{post.ID}:", err
                  callback()
            
            img.onerror = ->
               console.warn "Failed to load image #{post.ID}"
               callback()

         # Async Queue Processing
         queue = []
         g.posts.forEach (post) -> if post.file then queue.push post
         
         total = queue.length
         console.log "Total images to process:", total
         
         if total is 0
            new Notice 'warning', "No images to simulate.", 3
            return

         new Notice 'info', "Simulating dupes for #{total} images...", 3
         
         next = ->
            if queue.length is 0
               console.log "All images processed. Generating ZIP..."
               # Finish DB Update
               newDB = JSON.stringify(db, null, 2)
               Conf['dhashDatabase'] = newDB
               $.set 'dhashDatabase', newDB
               
               # Add JSON to ZIP
               simFolder.file("database.json", newDB)
               
               new Notice 'success', "Added #{count} entries. Generating ZIP...", 5
               
               # Generate ZIP
               console.log "Starting ZIP generation..."
               zip.generateAsync {type: "blob", compression: "STORE"}
                 .then (content) ->
                    console.log "ZIP generated, size:", content.size
                    url = URL.createObjectURL(content)
                    a = $.el 'a',
                      href: url
                      download: "simulated_images_#{Date.now()}.zip"
                    a.click()
                    setTimeout ->
                       URL.revokeObjectURL(url)
                    , 60000
                    new Notice 'success', "ZIP Downloaded!", 5
                 .catch (err) ->
                    console.error "ZIP Generation Failed:", err
                    new Notice 'error', "ZIP Generation Failed: #{err}", 10
               
               console.log "Unlocking dHash Database..."
               return
               
            p = queue.shift()
            processPost p, ->
               ids_processed++
               console.log "Processed #{ids_processed}/#{total}"
               if ids_processed % 5 is 0
                  new Notice 'info', "Simulating: #{ids_processed}/#{total}...", 1
               next()
         
         next()

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
