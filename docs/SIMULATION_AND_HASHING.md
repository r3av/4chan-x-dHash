# dHash Simulation & Hashing System

## Overview
This document outlines the architecture of the **Simulate Image Dupes** feature and the underlying hashing mechanisms implemented in 4chan X (dHash fork). The system is designed to generate distinct visual variations of an image to test the robustness of the perceptual hashing algorithm (dHash) and to build a ground-truth dataset for duplicate detection.

## Database Structure
The dHash database has been refactored from a flat text format to a structured **JSON** store.

**File**: `Conf['dhashDatabase']` (LocalStorage)
**Structure**:
```json
{
  "dhash_hex_value": [
    {
      "board": "g",
      "num": "123456",          // Post ID
      "timestamp": 1709251200,  // Unix Epoch Seconds
      "md5": "1B2M2Y8AsgTpg...", // Base64 MD5 (Authentic)
      "name": "Anonymous",
      "trip": "!!tripcode"
    }
  ]
}
```

## Simulation Workflow
When running **Simulate Image Dupes Database Write**, the system processes visible thread images to generate a labeled dataset packaged in a ZIP file.

### 1. Image Variations
For each source image, we generate and categorize the following:

| Type | Suffix | Description | Hashing Method |
|------|--------|-------------|----------------|
| **Original** | `_original` | The raw full-res file from 4chan. | Use 4chan-provided MD5. |
| **Original Thumb**| `_original_thumb` | The actual thumbnail served by 4chan (`s.jpg`). | Fetch Blob -> Calculate SparkMD5. |
| **Sim Thumb** | `_sim_thumb` | Original resized to max 250px (Canvas). | Canvas -> Blob -> SparkMD5. |
| **Sim Crop90** | `_sim_crop90` | Center crop 90% of the image. | Canvas -> Blob -> SparkMD5. |
| **Sim JPEG50** | `_sim_jpeg50` | Thumb re-compressed at 50% quality. | Canvas -> Blob -> SparkMD5. |
| **Sim Shift** | `_sim_shift` | Image translated 1px right/down. | Canvas -> Blob -> SparkMD5. |

### 2. Output Format
- **ZIP Archive**: `simulated_images_[TIMESTAMP].zip`
  - `simulated/` (Folder)
    - `123456_original.jpg`
    - `123456_original_thumb.jpg`
    - `123456_sim_thumb.jpg`
    - ...
    - `database.json` (The full DB snapshot)

## Technical Architecture

### Dynamic Dependencies
To keep the main userscript lightweight, heavy libraries are loaded from CDNs only when the feature is actively used:
- **JSZip**: For client-side ZIP creation (`jszip.min.js`).
- **SparkMD5**: For calculating authentic MD5s of generated blobs (`spark-md5.min.js`).

### CORS & Canvas Taint
A major challenge in client-side image processing is **Canvas Taint**. If an image is loaded into a `<canvas>` element from a cross-origin source (like `i.4cdn.org`), the browser blocks `getImageData` and `toBlob` for security.
**Solution**:
1. Fetch the image as a raw `Blob` using `XMLHttpRequest`.
2. Create a local Object URL: `URL.createObjectURL(blob)`.
3. Load this Object URL into the `Image` object.
4. The browser treats this as same-origin, allowing full Canvas manipulation.
5. **Clean up**: `URL.revokeObjectURL` is called after processing to prevent memory leaks.

### MD5 Formatting
- **SparkMD5** outputs a Hex string (e.g., `098f6bcd...`).
- **4chan** uses Base64 encoded MD5 (e.g., `CY9rz...`).
- We convert Hex -> Base64 manually: `btoa(hexToBytes(str))` to ensure consistency across the database.

## Unit Test Plan (Future)

To ensure long-term stability without manual "Gauntlet" runs, we propose the following unit tests:

### 1. Hashing Algorithm Stability
*   **Goal**: Ensure `DHash.computeHash` returns idempotent results.
*   **Method**: 
    - Load a clear 10x10 black-and-white checkerboard pattern.
    - Verify hash is exactly `aaaa5555...`.
    - Rotate image 90 degrees, verify hash changes deterministically.

### 2. Simulation Fidelity
*   **Goal**: Ensure simulations (Crop, Resize) don't drift.
*   **Method**:
    - Input: Known constant image (e.g., pure red square).
    - Action: Run `Sim Thumb`.
    - Assert: Resulting blob size is within expected range; dHash is identical (flat color).

### 3. Database Integrity
*   **Goal**: Prevent regression in JSON structure.
*   **Method**:
    - Mock `Conf['dhashDatabase']`.
    - Run `addEntry`.
    - Assert: New entry is correctly appended to the key array; Timestamp is valid Unix epoch.

### 4. Integration / ZIP
*   **Goal**: Verify ZIP is generated correctly.
*   **Method**:
    - Trigger `writeSimulatedDatabase` with 1 mocked image.
    - Intercept `zip.generateAsync`.
    - Assert: ZIP contains exactly 7 items (Original + 5 Sims + JSON).
