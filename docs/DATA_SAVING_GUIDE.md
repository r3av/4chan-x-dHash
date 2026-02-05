# dHash & Filter Data Saving Guide

**Version**: `1.14.23.2.3`  
**Date**: 2026-02-04

## Overview
As of version `1.14.23.2.3`, 4chan X with dHash introduces robust verification and data collection capabilities. This allows users to save metadata (post #, name, tripcode, filename, comment, etc.) for posts that trigger specific filters or have their dHash calculated. This data is stored persistently and can be used for verification, dataset creation, or auditing filter performance.

## Settings & Configuration
These options are located under **Settings > Filtering**.

### 1. Global Data Collection
*   **Save Thread Data**:  
    Collects metadata for **every** image post where a dHash is calculated, regardless of whether it was filtered.
    *   *Warning*: This collects data for every image in every thread you visit. Use with caution as it can increase storage usage and JSON size rapidly.

### 2. Granular Filter Saving
These options allow you to save metadata **only** when a specific filter type triggers on a post. This is useful for building targeted datasets (e.g., "all posts by this tripcode" or "all posts matching this MD5").

*   **Save dHash Filtered Post Data**: Saves data when an image is hidden by dHash (exact or close match).
*   **Save MD5 Filtered Post Data**: Saves data when an image is hidden by strict MD5 hash.
*   **Save Name / Tripcode / Filename / Comment Filtered Post Data**: Saves data when a post is hidden by the respective text filter.

**Note**: If multiple filters catch a post, the "Reason Added" priority ensures the most specific reason is recorded (see Priority System below).

## Management Tools

### Force Add Data Button
Located in **Settings > Filtering**.

*   **Purpose**: Update existing dHash entries with missing metadata.
*   **How it works**: It scans all posts currently loaded in your tab. If a post corresponds to an entry already in your database (matched by dHash), it will:
    1.  Fill in any missing properties (e.g., if you previously only saved file hashes but now want to save Names/Tripcodes).
    2.  Update the "Reason Added" if the current session provides a higher-priority reason (e.g., upgrading "Thread-wide" to "dHash Matched").
*   **Use Case**: You enabled "Save Name Filtered Post Data" *after* opening a thread. Click "Force Add Data" to backfill the name data for posts that are already there.

### dHash Data Tab
Located in **Settings > dHash Data**.

*   **View & Edit**: A raw text area displaying the stored JSON database (`Conf['dhash_post_data']`).
*   **Backup**: You can copy/paste this text to back up your collected data.

## Data Structure & Priority
Data is stored in `dhash_post_data` as a JSON object keyed by the image's dHash.

### Priority System
When a post is processed, the system assigns a `reason_added`. Higher priority reasons overwrite lower ones:
1.  **Manual** (Highest)
2.  **dHash Matched** (Exact)
3.  **dHash Matched** (Close)
4.  **MD5**
5.  **Text Filters** (Name, Trip, Comment, etc.)
6.  **Thread-wide** (Lowest - collected just because 'Save Thread Data' is on)

### Entry Format
```json
{
  "hash_string": [
    {
      "board": "g",
      "num": 12345678,
      "filehash": "MD5_STRING",
      "filename": "image.jpg",
      "timestamp": 1700000000,
      "name": "Anonymous",
      "trip": "!!tripcode",
      "text": "Comment text...",
      "reason_added": "filtered by tripcode"
    }
  ]
}
```

## Technical Implementation

### Key Files
*   **`src/Filtering/DHash.coffee`**:
    *   **Core Logic**: Contains the `collect` function, which handles the creation and updating of data entries.
    *   **State Management**: Manages `DHash.postData` (in-memory storage) and the `forceAdd` flag.
    *   **Hashing**: Handles the dHash calculation (`computeHash`) and triggers collection.
*   **`src/General/Settings.coffee`**:
    *   **UI Integration**: Injects the "Force Add Data" button and the "dHash Data" textarea into the settings menu.
    *   **Event Handling**: The "Force Add Data" click handler iterates through `DHash.postData`, matches with `g.posts` (live posts), and triggers re-collection.
*   **`src/config/Config.coffee`**:
    *   **Definitions**: Defines the configuration keys for the new settings (e.g., `'Save dHash Filtered Post Data'`, `'dhash_post_data'`).

### Logic Flow

#### 1. Data Collection (`DHash.collect`)
The `collect` function is the central hub for saving data.
*   **Input**: `post`, `file`, `reason`
*   **Process**:
    1.  Checks if any "Save Data" setting is enabled.
    2.  Constructs a standardized `entry` object with metadata.
    3.  Checks if the entry already exists in `DHash.postData` (by board & post ID).
    4.  **Merging Strategy**:
        *   If `DHash.forceAdd` is **true**: The existing entry is forcibly updated. Missing keys are added, and the `reason_added` is updated if the new reason has higher priority.
        *   If `DHash.forceAdd` is **false**: The entry is only updated if the new `reason_added` has a higher priority than the existing one.
    5.  Sets `DHash.dataChanged = true` to trigger a save on the next cycle.

#### 2. Persistence (`DHash.saveData`)
*   Called periodically (via `requestIdleCallback` loop in `DHash.run`) or manually.
*   Checks `DHash.dataChanged` flag.
*   Serializes `DHash.postData` to JSON and saves it to `Conf['dhash_post_data']` (backed by `localStorage`/`GM_setValue`).

#### 3. Filtering Integration (`DHash.check` / `Filter.test`)
*   When `DHash.compute` processes an image, it calls `Filter.test`.
*   If `Filter.test` returns a match, `DHash` inspects `match.key` (e.g., 'MD5', 'tripcode').
*   If the corresponding "Save ... Filtered Post Data" setting is enabled, it triggers `DHash.collect` with the specific reason (e.g., "filtered by tripcode").

#### 4. Force Add Button Logic
1.  Iterates `DHash.postData` keys (hashes).
2.  Iterates entries for each hash.
3.  Lookups up the post object in `g.posts` (cache of currently loaded posts).
4.  If found and loaded, calls `DHash.collect(post, file, entry.reason_added)` with `DHash.forceAdd = true`.
