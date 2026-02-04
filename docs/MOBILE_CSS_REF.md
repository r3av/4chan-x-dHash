# Mobile CSS & Layout Refinements
**Version**: 1.14.23.2.3
**Date**: 2026-02-03
**Status**: Implemented & Verified

## Overview
This document details the mobile layout refinements implemented to match the native 4chan responsive experience on mobile devices (width <= 480px) within 4chan X.

## Implementation Details

### 1. Mobile Styles (`src/css/style.css`)
All mobile-specific overrides are strictly contained within the `@media only screen and (max-width: 480px)` query to prevent desktop regressions.

#### Key Rules:
*   **Body Overflow**: `overflow-x: hidden` is applied to `body` and `html` to prevent horizontal scrolling, common on iOS when elements slightly exceed the viewport.
*   **Header Bar Constraint**: `#header-bar` is forced to `width: 100%`, `box-sizing: border-box`, and `min-width: 0` to ensure it doesn't push the page width beyond the viewport.
*   **Post Info Layout**:
    *   `display: block` forced on `.postInfo`.
    *   Flex-like arrangement with Name/Tripcode on the left and Date/PostNum on the right.
    *   Background color `#c9cde8` to match native mobile theme.
*   **Menu Button**:
    *   Repositioned using `position: absolute` to the top-left of the post.
    *   Rotated 90 degrees (`transform: rotate(90deg)`) to mimic the vertical "..." menu.
    *   **Font Size**: Explicitly set to `13px` (approx 16pt visual equivalent on some screens, but scaled down request) per feedback.
*   **Blotter**: `#blotter.desktop` is explicitly hidden (`display: none`) to prevent table overflow.

### 2. File Information (`src/Images/MobileLayout.coffee`)
Separate logic was implemented to handle file information display in collapsed vs. expanded states.

*   **Logic**:
    *   Injects two separate elements after the thumbnail:
        1.  `.mFileInfo.mobile`: Contains "Size Type" (e.g., "190 KB JPG").
        2.  `.mFilename.mobile`: Contains the full filename (e.g., "image.jpg").
*   **Toggle Behavior** (via CSS):
    *   **Collapsed**: `.mFileInfo` is visible. `.mFilename` is hidden.
    *   **Expanded** (`.image-expanded` class present): `.mFileInfo` is hidden. `.mFilename` is visible below the full image.
    *   **Guard Clause**: Added a check to prevent duplicate injection of these elements if they already exist, fixing a "double file size" bug.

## Issues Encountered & Learnings

### 1. Horizontal Scroll on Mobile
*   **Issue**: The page allowed horizontal scrolling on mobile devices (iOS), showing empty space on the right.
*   **Cause**:
    1.  `#header-bar` had a fixed width or lacked constraint, exceeding the 430px body width.
    2.  `table#blotter.desktop` (wide element) was remaining visible in the DOM.
*   **Fix**:
    *   **Header**: Forced `width: 100%`, `box-sizing: border-box`, `left: 0`, `right: 0`.
    *   **Blotter**: Added `#blotter.desktop { display: none !important; }`.
    *   **Body**: Added `overflow-x: hidden` as a global safeguard.

### 2. CSS Scope Leak (Desktop Regression)
*   **Issue**: Mobile styles (like `display: block` for `.postInfo`) leaked into the desktop view analysis.
*   **Cause**: A premature closing brace `}` in `style.css` closed the media query block early.
*   **Fix**: Validated CSS nesting and removed the stray brace/text.
*   **Lesson**: Always double-check media query closure when editing large CSS files in chunks.

### 3. Font Size Discrepancies
*   **Issue**: `.menu-button` font calculation varied unpredictably (16pt becoming 21px+).
*   **Fix**: Switched to explicit `px` units (`13px`) for consistent rendering across devices, moving away from `pt` which depends on browser DPI handling.

### 4. Duplicate Element Injection
*   **Issue**: "190 KB JPG" appeared twice below the thumbnail.
*   **Cause**: `MobileLayout` node callback triggered multiple times or on re-scans without checking existence.
*   **Fix**: Added `return if $('.mFileInfo.mobile', @file.text.parentNode)` to skip regular injection if already present.

## Future Reference
*   **Testing**: Always verify mobile layouts by explicitly resizing the browser window *and* checking `scrollWidth` vs `offsetWidth`.
*   **Experimentation**: Be willing to use `overflow: hidden` on parent containers if child elements (like ads or blotters) stubbornly exceed viewport width.

## Native 4chan Insights & Research Protocol

### Research Methodology
To accurately tackle mobile CSS issues, we analyze the **native responsive behavior** of `boards.4chan.org`.
**CRITICAL**: Do NOT use `p.4chan.org` (the dedicated mobile site) for reference. It uses a completely different HTML structure and legacy CSS that does not map to the main site's structure which 4chan X enhances.

### Reference Steps (Future Agents)
When verifying or researching native behavior:
1.  **Use `boards.4chan.org`**: Navigate to a standard thread URL (e.g., `https://boards.4chan.org/g/thread/12345`).
2.  **Clean Environment**:
    *   Use **Incognito/Private Mode** to ensure no cached scripts or cookies interfere.
    *   **Disable 4chan X**: Turn off Violentmonkey/Tampermonkey or specifically disable the script. We must see the raw 4chan CSS/HTML.
3.  **Simulate Mobile**:
    *   Resize your desktop browser window to `< 480px` width.
    *   OR use Chrome/Firefox DevTools "Device Toolbar" (Ctrl+Shift+M) and select a mobile device (iPhone, Pixel).
    *   Observe how the native site rearranges elements (e.g., how `.postInfo` flex-wraps, how margins adjust).

### Native Behavior Notes
*   **Menu Button**: Native responsive CSS hides the standard "delete" checkbox and replaces/transforms the UI into a menu dropdown.
*   **Post Layout**: Native mobile layout drastically simplifies margins and font sizes.
*   **Scroll**: Native 4chan ensures strict vertical scrolling; any horizontal scroll usually indicates a layout bug (e.g., a long URL or code block not wrapping).
