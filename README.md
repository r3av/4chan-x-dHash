# 4chan X v1.14.23.2 with dHash
> **Forked from [ccd0/4chan-x](https://github.com/ccd0/4chan-x)**

## 1. Overview
This is a fork of 4chan X with dHash filtering added. The dHash feature calculates a perceptual hash called dHash for an image. This hash allows users to filter duplicate images even if they have slightly different metadata, resolution, or compression, as "similar looking" images produce identical or near-identical hashes.

- **This means that if you filter an image with dHash, any future images that are similar to the original image will also be hidden _even if the md5 hash is different_.**

**How it works**: The algorithm resizes the image to a standardized 9x8 grid, converts it to grayscale, and compares pixel brightness gradients. This generates a compact 64-bit "fingerprint" that ignores file format or small visual artifacts. **It utilizes fuzzy matching (Hamming distance) to catch images that are extremely close but not byte-for-byte identical.**

**Attribution**: The difference hash (dHash) algorithm used here is based on the work of **Neal Krawetz** (see [Kind of Like That](https://www.hackerfactor.com/blog/index.php?/archives/529-Kind-of-Like-That.html)).

## 2. Install

Use the userscript in the [/testbuilds/](testbuilds/) directory to install and test it out.
- Backup your current 4chan X installation and settings.
- Disable your current 4chan X installation.
- Install the [userscript](testbuilds/4chan-X.user.js) in Tampermonkey or Greasemonkey.
 
## 3. Configuration and Usage
To enable, go to the 4chan X settings and enable the Image dHash feature. 
- 4chan X Settings -> Main -> Filtering -> Check the Image dHash checkbox.

To use, filter any image like you would normally would with MD5, but select the dHash option instead of the MD5 option.
- Select the dropdown menu in the top right corner of a post.
- Navigate the **dropdown menu -> Filter -> Image dHash**
- Image dHash will be saved to the dHash filter list, which can be accessed from 4chan X settings in the top right.
- Refresh the page to immediately see the results and voila, it will be hidden. **Now any future image that is similar to the original image will also be hidden.**

The feature is controlled by the following settings in `Config.coffee`:
- **Image dHash**: Main toggle to enable/disable the feature.
- **Show dHash Calculation Progress**: Enables a progress counter in the header (e.g., `dHash: 50/150`).
- **Show dHash Status**: Enables a persistent status indicator in the header (`dHash: On`).
- **dHash Stats**: Enables persistent statistics in the header (`Filtered: 5 | New MD5s: 2`).
- **Save dHash MD5s**: Automatically adds the MD5 of any image hidden by a dHash filter to the MD5 filter list.

## 4. Caveats
Implementing perceptual hashing introduces new background processing compared to standard 4chan X.

> [!WARNING]
> **Possible Performance Impact**: dHash may perform additional **calculations** on every thumbnail. While your browser naturally downloads and renders images during normal browsing, dHash adds a layer of background pixel analysis. To ensure a smooth experience, we utilize extensive caching and efficient job queues. We also specifically target the thumbnail images to minimize bandwidth usage, as users already download the thumbnail images in a regular viewing experience. However, users on low-end devices should be aware of the increased CPU usage.

This necessity for background processing leads to a key architectural difference:

#### Why is dHash implemented differently from MD5?
The native **MD5 Filter** relies entirely on metadata provided by 4chan's servers (`data-md5` attributes). It is instant and requires zero bandwidth because the browser doesn't need to download the image to know its hash.

**dHash**, however, is not provided by 4chan. To calculate it, the extension must:
1.  **Download** the image (specifically the **thumbnail** to save bandwidth).
2.  **Render** the image to a canvas.
3.  **Process** the pixel data.

Because scanning every thread requires hundreds of network requests and CPU operations, a simple synchronous loop (like MD5) would freeze the browser. Therefore, our implementation uses an **asynchronous job queue** with `requestIdleCallback` to process images in the background without blocking the UI. This may cause images to "pop in" briefly before being hidden, unlike the instant-hide of MD5 filters.

## 5. Core Architecture
The implementation is split into two main modules: `DHash` (image processing) and `Filter` (applying rules).

### 5.1 Image Loading & Preparation (`DHash.coffee`)
The `DHash` module hooks into the `Callbacks.Post` and `PostsInserted` events. 
- **Parallel Loading**: When a post is detected, we immediately trigger the image load. We force `crossOrigin = 'anonymous'` to ensure we can read the image data from the canvas without security errors.
- **Event-Driven**: The hashing process is triggered only *after* the image has fully loaded (`img.onload`). This allows the browser to handle multiple network requests in parallel.
- **MD5 Caching**: Before preparing an image, we check if its MD5 is already in `DHash.md5Cache`. If found, we reuse the cached dHash instantly.

### 5.2 Job Queue System
To prevent freezing the UI when a large thread is loaded, hashing is decoupled from loading.
- **Queue**: Loaded images are pushed into a generic `DHash.queue`.
- **Throttling**: The `requestIdleCallback` API (or a `setTimeout` fallback) is used to process the queue. This ensures that hashing only happens when the browser is idle, keeping the scrolling smooth.
- **Processing**: One image is processed at a time. The `run` loop shifts a task from the queue, computes the hash, and then schedules the next run.

### 5.3 Hashing Algorithm (`DHash.computeHash`)
We implement a standard horizontal difference hash (dHash):
1. **Resize**: Draw the image to a canvas with dimensions 9x8.
2. **Grayscale**: Convert pixels to grayscale values.
3. **Compare**: Compare each pixel to its right neighbor. If the left pixel is brighter, the bit is set to 1, otherwise 0.
4. **Hex Output**: The resulting 64 comparisons form a 64-bit integer, represented as a hexadecimal string.

### 5.4 Filtering (`Filter.coffee` integration)
- **Hash Assignment**: Once computed, the hash is stored on the file object (`file.dhash`).
- **Dynamic Updates**: The `Filter` module listens for changes to the configuration using `$.sync`. 
    - When a filter is added (e.g., via the menu), `Filter.load()` is called.
    - This triggers a re-scan of **all existing posts** to immediately hide any that match the new rule.
- **Logic**: `Filter.test()` checks the `dhash` property against user-defined regular expressions or strings.
- **Auto-MD5 Saving**: If `Save dHash MD5s` is enabled, any post hidden by `Filter.test()` due to a dHash match will have its MD5 added to the `MD5` filter list in the specified format (`/MD5_HASH/`).

## 6. Performance Considerations
- **Non-Blocking**: Heavy computation stays off the main rendering path via `requestIdleCallback`.
- **Parallel Network**: Image fetching happens concurrently, maximizing bandwidth usage.
- **MD5 Cache**: Hashes are computed once per MD5. Duplicate files (e.g., in a Quote Preview or multiple posts with same image) leverage the already computed dHash instantly.
