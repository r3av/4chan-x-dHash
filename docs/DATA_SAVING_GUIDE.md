# dHash & Filter Data Saving Guide

**Version**: `1.14.23.2.4`  
**Date**: 2026-02-05

## Overview
As of version `1.14.23.2.4`, 4chan X with dHash introduces robust verification and data collection capabilities. This allows users to save metadata (post #, name, tripcode, filename, comment, etc.) for posts that trigger specific filters or have their dHash calculated. This data is stored persistently and can be used for verification, dataset creation, or auditing filter performance.

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

### dHash Data Tab
Located in **Settings > dHash Data**.

*   **View & Edit**: A raw text area displaying the stored JSON database (`Conf['dhash_post_data']`).
*   **Backup**: You can copy/paste this text to back up your collected data.
*   **Sort by Date**: Toggle button to sort the database. First click sorts newest-to-oldest, second click sorts oldest-to-newest. Affects both the order of hash groups and entries within them.

### Force Add Data Button
Located in **Settings > Filtering**.

*   **Purpose**: Update existing dHash entries with missing metadata.
*   **How it works**: It scans all posts currently loaded in your tab. If a post corresponds to an entry already in your database (matched by dHash), it will:
    1.  Fill in any missing properties (e.g., if you previously only saved file hashes but now want to save Names/Tripcodes).
    2.  Update the "Reason Added" if the current session provides a higher-priority reason (e.g., upgrading "Thread-wide" to "dHash Matched").
*   **Use Case**: You enabled "Save Name Filtered Post Data" *after* opening a thread. Click "Force Add Data" to backfill the name data for posts that are already there.

### Remove Page Posts Button
Located in **Settings > dHash Data**.

*   **Purpose**: Remove all entries from the database that belong to the currently viewed page.
*   **Behavior**:
    *   Identifies all posts on the current page.
    *   Removes corresponding entries from `Conf['dhash_post_data']`.
    *   Clears the in-memory `DataSaver.postData`.
    *   Resets the `dataChanged` flag.
*   **Use Case**: You want to clear the database for the current thread, perhaps to start fresh or because the data is no longer relevant.

### Sort by Date Button
Located in **Settings > dHash Data**.

*   **Purpose**: Sort the database by date.
*   **Behavior**:
    *   First click sorts newest-to-oldest.
    *   Second click sorts oldest-to-newest.
    *   Affects both the order of hash groups and entries within them.
*   **Use Case**: You want to sort the database by date.

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
      "thread_num": 12345678,
      "reason_added": "dhash matched close to existing dhash Ham: <4> Matching dHash: <...>"
    }
  ]
}
```

## Technical Implementation

### Key Files & Dependencies

*   **`src/Filtering/DataSaver.coffee`**:
    *   **Core Logic**: Contains the `collect` and `saveData` functions.
    *   **State Management**: Manages `DataSaver.postData` (in-memory storage), `dataChanged` flag, and `forceAdd` flag.
    *   **Persistence**: Handles saving to `Conf['dhash_post_data']` and `localStorage`.
    *   **Dependencies**:
        | From | Uses |
        |------|------|
        | `Conf` (global) | `Conf['dhash_post_data']`, `Conf['Save Thread Data']`, etc. |
        | `$` (helpers) | `$.on`, `$.set` |
        | `window` (browser) | `beforeunload` event |

*   **`src/Filtering/DHash.coffee`**:
    *   **Hashing**: Computes perceptual hash (`computeHash`) and delegates saving to `DataSaver`.
    *   **Filter Check**: Inspects `Filter.test` results and determines the appropriate `reason`.
    *   **Dependencies**:
        | From | Uses |
        |------|------|
        | `DataSaver` | `DataSaver.init()`, `DataSaver.collect()`, `DataSaver.saveData()` |
        | `Filter` | `Filter.test()`, `Filter.addFilter()`, `Filter.filters` |
        | `Conf` (global) | Settings flags |
        | `Callbacks.Post` | Registering post processing callbacks |
        | `g` (global) | `g.posts`, `g.VIEW` |
        | `PostHiding`, `ThreadHiding` | `.hide()` methods |

*   **`src/General/Settings.coffee`** (dHash Data section):
    *   **UI Integration**: Injects "Force Add", "Remove Page Posts", "Sort by Date" buttons.
    *   **Event Handlers**: Implements button click logic for each action.
    *   **Dependencies**:
        | From | Uses |
        |------|------|
        | `DataSaver` | `DataSaver.postData`, `DataSaver.saveData()`, `DataSaver.forceAdd`, `DataSaver.collect()` |
        | `Conf` (global) | `Conf['dhash_post_data']` |
        | `g` (global) | `g.posts` (for Force Add and Remove Page Posts) |
        | `$` (helpers) | `$`, `$.on`, `$.set` |
        | `Notice` | User feedback notifications |

*   **`src/Filtering/Filter.coffee`**:
    *   **Test Logic**: Returns `match.key`, `match.distance` (for dHash), and `match.regexp` (the matching filter string/pattern).
    *   **Dependencies**:
        | From | Uses |
        |------|------|
        | `DataSaver` | `DataSaver.collect()`, `DataSaver.saveData()` (in `makeFilter` callback) |
        | `Conf` (global) | Filter settings |
        | `g` (global) | `g.posts`, `g.VIEW` |
        | `PostHiding`, `ThreadHiding` | `.hide()`, `.show()` methods |

---

### Logic Flow

#### 1. Initialization (`DataSaver.init`)
Called once during extension load (via `DHash.init`).
```coffeescript
DataSaver.postData = JSON.parse(Conf['dhash_post_data'] or '{}')
$.on window, 'beforeunload', DataSaver.saveData
```
- Loads existing data from `Conf`.
- Registers `beforeunload` listener to persist unsaved changes.

---

#### 2. Data Collection (`DataSaver.collect`)
```
Input: post, file, reason
```
1.  **Guard**: Returns early if no "Save Data" settings are enabled.
2.  **Construct Entry**: Builds a metadata object:
    ```json
    { "board", "num", "thread_num", "filehash", "filename", "timestamp", "name", "text", "trip", "preview_w", "preview_h", "media_w", "media_h", "reason_added" }
    ```
3.  **Keying**: Uses `file.dhash` as the primary key for grouping.
4.  **Priority Calculation**: Assigns a numeric priority to determine which `reason_added` takes precedence:
    | Reason | Priority |
    |--------|----------|
    | `manual` | 100 |
    | `dhash matched existing dhash` (exact) | 90 |
    | `dhash matched close...` | 80 |
    | `from existing md5` | 70 |
    | `filtered by ...` | 60 |
    | `thread-wide` | 10 |
5.  **Duplicate Handling**:
    *   **If entry exists (same `board.num`)**:
        *   **`forceAdd = true`**: Overwrites with new data, but keeps the higher-priority `reason_added`.
        *   **`forceAdd = false`**: Only updates `reason_added` if new priority > existing.
    *   **If entry is new**: Appends to the hash's array.
6.  **Dirty Flag**: Sets `DataSaver.dataChanged = true`.

---

#### 3. Persistence (`DataSaver.saveData`)
- **Trigger**: Called on `beforeunload` event or manually after queue processing.
- **Guard**: Returns early if no "Save Data" settings are enabled OR `dataChanged` is `false`.
- **Action**: Serializes `DataSaver.postData` to JSON (pretty-printed) and saves to:
    - `Conf['dhash_post_data']` (in-memory config)
    - `$.set 'dhash_post_data', json` (persistent storage via `GM_setValue` or `localStorage`)
- **Reset**: Sets `dataChanged = false`.

---

#### 4. Filtering Integration (`DHash.check`)
When `Filter.test` returns a match with `hide = true`:
1.  Inspects `matches` array for trigger keys (`dhash`, `MD5`, `name`, etc.).
2.  Constructs a `reason` string based on the highest-priority match:
    *   dHash: `"dhash matched close to existing dhash Ham: <N> Matching dHash: <hash>"`
    *   MD5: `"from existing md5"`
    *   Text filters: `"filtered by <key>"`
3.  Calls `DataSaver.collect(post, file, reason)`.

---

#### 5. UI Actions (Settings.coffee)

##### Force Add Data
1.  Sets `DataSaver.forceAdd = true`.
2.  Iterates all entries in `DataSaver.postData`.
3.  Looks up live `post` object in `g.posts` cache.
4.  If found, calls `DataSaver.collect(post, file, entry.reason_added)` to backfill properties.
5.  Resets `forceAdd = false` and saves.

##### Remove Page Posts
1.  Builds a lookup of current page posts (`g.posts`).
2.  Filters out entries matching `board.num` from `DataSaver.postData`.
3.  Deletes empty hash groups.
4.  Saves directly to `Conf` and updates the textarea.

##### Sort by Date
1.  Maintains a `sortNewestFirst` toggle (closure variable).
2.  Sorts each hash group's entries by `timestamp`.
3.  Sorts hash groups by their first entry's timestamp.
4.  Saves and toggles `sortNewestFirst` for next click.
