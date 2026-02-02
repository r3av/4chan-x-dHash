# 4chan X v1.14.23.2
> **Forked from [ccd0/4chan-x](https://github.com/ccd0/4chan-x)**

# dHash Implementation in 4chan X

This document outlines the design and implementation details of the perceptual image hashing (dHash) feature in 4chan X.

## 1. Overview
The dHash feature calculates a perceptual hash for every image thumbnail on the page. This hash allows users to filter duplicate images even if they have slightly different metadata, resolution, or compression, as "similar looking" images produce identical or near-identical hashes.

**Attribution**: The difference hash (dHash) algorithm used here is based on the work of **Neal Krawetz** (see [Kind of Like That](https://www.hackerfactor.com/blog/index.php?/archives/529-Kind-of-Like-That.html)).

#### Why is dHash implemented differently from MD5?
The native **MD5 Filter** relies entirely on metadata provided by 4chan's servers (`data-md5` attributes). It is instant and requires zero bandwidth because the browser doesn't need to download the image to know its hash.

**dHash**, however, is not provided by 4chan. To calculate it, the extension must:
1.  **Download** the image (specifically the **thumbnail** to save bandwidth).
2.  **Render** the image to a canvas.
3.  **Process** the pixel data.

Because scanning every thread requires hundreds of network requests and CPU operations, a simple synchronous loop (like MD5) would freeze the browser. Therefore, our implementation uses an **asynchronous job queue** with `requestIdleCallback` to process images in the background without blocking the UI. This may cause images to "pop in" briefly before being hidden, unlike the instant-hide of MD5 filters.

## 2. Configuration
The feature is controlled by the following settings in `Config.coffee`:
- **Image dHash**: Main toggle to enable/disable the feature.
- **Show dHash Calculation Progress**: Enables a progress counter in the header (e.g., `dHash: 50/150`).
- **Show dHash Status**: Enables a persistent status indicator in the header (`dHash: On`).
- **dHash Stats**: Enables persistent statistics in the header (`Filtered: 5 | New MD5s: 2`).
- **Save dHash MD5s**: Automatically adds the MD5 of any image hidden by a dHash filter to the MD5 filter list.

## 3. Core Architecture
The implementation is split into two main modules: `DHash` (image processing) and `Filter` (applying rules).

### 3.1 Image Loading & Preparation (`DHash.coffee`)
The `DHash` module hooks into the `Callbacks.Post` and `PostsInserted` events. 
- **Parallel Loading**: When a post is detected, we immediately trigger the image load. We force `crossOrigin = 'anonymous'` to ensure we can read the image data from the canvas without security errors.
- **Event-Driven**: The hashing process is triggered only *after* the image has fully loaded (`img.onload`). This allows the browser to handle multiple network requests in parallel.
- **MD5 Caching**: Before preparing an image, we check if its MD5 is already in `DHash.md5Cache`. If found, we reuse the cached dHash instantly.

### 3.2 Job Queue System
To prevent freezing the UI when a large thread is loaded, hashing is decoupled from loading.
- **Queue**: Loaded images are pushed into a generic `DHash.queue`.
- **Throttling**: The `requestIdleCallback` API (or a `setTimeout` fallback) is used to process the queue. This ensures that hashing only happens when the browser is idle, keeping the scrolling smooth.
- **Processing**: One image is processed at a time. The `run` loop shifts a task from the queue, computes the hash, and then schedules the next run.

### 3.3 Hashing Algorithm (`DHash.computeHash`)
We implement a standard horizontal difference hash (dHash):
1. **Resize**: Draw the image to a canvas with dimensions 9x8.
2. **Grayscale**: Convert pixels to grayscale values.
3. **Compare**: Compare each pixel to its right neighbor. If the left pixel is brighter, the bit is set to 1, otherwise 0.
4. **Hex Output**: The resulting 64 comparisons form a 64-bit integer, represented as a hexadecimal string.

### 3.4 Filtering (`Filter.coffee` integration)
- **Hash Assignment**: Once computed, the hash is stored on the file object (`file.dhash`).
- **Dynamic Updates**: The `Filter` module listens for changes to the configuration using `$.sync`. 
    - When a filter is added (e.g., via the menu), `Filter.load()` is called.
    - This triggers a re-scan of **all existing posts** to immediately hide any that match the new rule.
- **Logic**: `Filter.test()` checks the `dhash` property against user-defined regular expressions or strings.
- **Auto-MD5 Saving**: If `Save dHash MD5s` is enabled, any post hidden by `Filter.test()` due to a dHash match will have its MD5 added to the `MD5` filter list in the specified format (`/MD5_HASH/`).

## 4. Performance Considerations
- **Non-Blocking**: Heavy computation stays off the main rendering path via `requestIdleCallback`.
- **Parallel Network**: Image fetching happens concurrently, maximizing bandwidth usage.
- **MD5 Cache**: Hashes are computed once per MD5. Duplicate files (e.g., in a Quote Preview or multiple posts with same image) leverage the already computed dHash instantly.
