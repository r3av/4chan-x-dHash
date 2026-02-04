# Development Workflow

This document outlines the recommended workflow for developing 4chan X on Windows, including automatic rebuilding and live browser reloading.

## 1. Prerequisites
*   **Node.js**: Required for build tools.
*   **Make**: `mingw32-make` is required to run the build commands.
*   **PowerShell**: For running the file watcher.
*   **Browser Extension**: Tampermonkey (Chrome/Edge/Firefox) or Violentmonkey.

## 2. Automatic Rebuilding (`watch.ps1`)
To avoid manually running `make` after every change, use the provided PowerShell script `watch.ps1`. This script monitors the `src` directory and triggers a rebuild whenever a file is changed, created, deleted, or renamed.

### Usage
1.  Open PowerShell in the project root.
2.  Run the script:
    ```powershell
    .\watch.ps1
    ```
3.  The script will start monitoring. When you save a file, you should see:
    ```text
    Change detected in C:\path\to\file. Rebuilding...
    ```
4.  Keep this running in the background while you work.

## 3. Live Browser Loading (Local Loader)
Instead of reinstalling the UserScript after every build, you can set up a "Loader" script in your browser extension. this loader will pull the compiled script directly from your local disk.

### Setup Instructions
1.  **Allow File Access**:
    *   Go to your browser's extension management page (e.g., `chrome://extensions`).
    *   Find Tampermonkey.
    *   Enable **"Allow access to file URLs"**. This is critical for the `@require file:///...` directive to work.

2.  **Create the Loader Script**:
    *   Open Tampermonkey and create a new script.
    *   Paste the following metadata block. **Update the path** to match your actual project location.

```javascript
// ==UserScript==
// @name        4chan X with Dhash [DEV]
// @namespace   4chan-x-dev
// @version     1.0.0
// @description Local development loader for 4chan X
// @author      r3av
// @match       *://*.4chan.org/*
// @match       *://*.4channel.org/*
// @match       *://*.4cdn.org/*
// @grant       all
// @require     file:///C:/Users/Ryan/github%20projects/4chan-x/testbuilds/4chan-X-beta.user.js
// ==/UserScript==
```

### How it Works
*   The `@require` directive tells Tampermonkey to load the code from the absolute file path specified.
*   The `watch.ps1` script rebuilds the code to `testbuilds/4chan-X-beta.user.js`.
*   When you reload a 4chan page, Tampermonkey re-reads the file from disk, instantly applying your latest build.

### Troubleshooting
*   **"Not allowed to load local resource"**: Ensure "Allow access to file URLs" is enabled for the extension.
*   **Changes not showing**: Check the PowerShell window to ensure the build succeeded. Inspect the Tampermonkey dashboard to verify the loader script is enabled and running.
