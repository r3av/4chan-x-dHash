# Caching and GUI Analysis

**Date:** 2026-02-02
**Stable Version:** v1.14.23.2.2

## 1. Caching & Storage Analysis

### What is stored?
*   **MD5 Cache (`DHash.md5Cache`)**: A simple in-memory dictionary mapping MD5 hashes to their calculated dHash. This prevents re-calculating the dHash for the same image multiple times on the same page.
*   **Filters**: Regular expressions and strings for blocked content, stored in the browser's extension storage (LocalStorage or Tampermonkey storage).
*   **Persistent vs. Ephemeral**:
    *   **dHash Cache**: Ephemeral. Resets on page reload.
    *   **Filter List**: Persistent. Saved to disk/local storage.

### Limits & Constraints
*   **In-Memory Cache**: Limited only by available RAM. Since it is cleared on reload, it practically never hits a limit.
*   **Persistent Storage**: Limited by the browser's quota for the extension (typically ~5MB for LocalStorage, or unlimited for Tampermonkey if permission is granted).

### "Database" Potential
*   4chan X **does not** currently possess a persistent MD5 -> dHash database.
*   To use this data as a database, one would need to modify `src/Filtering/DHash.coffee` to hook into the computation step and export/save the `{ md5, dhash }` pairs to an external persistent store (e.g., IndexedDB or a local server).

## 2. GUI System Analysis

### How it works
*   **No Framework**: 4chan X does not use a high-level UI framework (like React or Vue).
*   **Manual DOM**: All UI elements are constructed manually using helper functions like `$.el` (element creator) and `$.add` (append child).
*   **CSS**: Styling is handled by global CSS files (e.g., `src/css/style.css`), providing reusable classes like `.dialog`, `.section-container`, and `.overlay`.

### Creating Custom Dashboards
It is entirely feasible to create custom windows and dashboards using the existing codebase as an API.

**Key Components:**
*   **`UI.dialog(id, properties)`**: Located in `src/General/UI.coffee`. Creates a standard floating window.
*   **`UI.Menu`**: For creating context menus.
*   **`Settings.coffee`**: Serves as a great reference implementation for a complex, multi-tabbed UI.

**Implementation Strategy:**
To create a custom dashboard without modifying core files:
1.  Create a new module (e.g., `src/General/Dashboard.coffee`).
2.  Use `UI.dialog` to create the main container.
3.  Populate it using `$.el` to build your "textboxes, menus, dashboard" elements.
4.  Inject it into the page using `$.add d.body, yourDialog`.

This approach allows for robust custom tools that look native to the extension.
## 3. Settings Menu Infrastructure

### Configuration Architecture
The settings system is split between structure definition and UI logic:

*   **Config Definition (`src/config/Config.coffee`)**: Central repository for all available settings.
    *   Uses a nested object structure: `Category -> Feature -> [DefaultValue, Description, NestLevel]`.
    *   The `NestLevel` integer determines indentation and grouping in the UI, allowing for complex sub-option hierarchies without manual DOM mapping for every item.
*   **Live State (`Conf` object)**: A globally accessible object that holds the current active settings. This is synced with browser storage.

### UI Generation & Population
The Settings dialog (`src/General/Settings.coffee`) is built dynamically when requested:

1.  **Dialog Creation**: Uses `readHTML('Settings.html')` to initialze the overlay and tab structure.
2.  **Tab Registration**: Sections are added via `Settings.addSection(title, openFunction)`. This allows other modules to register their own settings tabs.
3.  **Automatic Form Building**:
    *   The `Main` tab iterates over `Config.main`.
    *   `addCheckboxes` recursively creates labels, checkboxes, and descriptions based on the `Config` definitions.
    *   Inputs are automatically mapped to their corresponding `Conf` keys.
4.  **Specialized Sections**: Tabs like `Filter`, `Sauce`, and `Advanced` use specific templates and logic for more complex inputs (textareas, tables, specialized buttons).

### Data Binding and Persistence
4chan X uses a reactive-lite approach for saving:
*   **Callback Handlers (`$.cb`)**: Pre-defined handlers like `$.cb.checked` and `$.cb.value` are attached to `change` events.
*   **Immediate Save**: When a user toggles a checkbox, the value is updated in the global `Conf` object and immediately written to persistent storage (LocalStorage or extension storage) via `$.set`.
*   **Abstracted Storage**: `$.get` and `$.set` provide a unified interface that handles storage across different environments (userscript managers, native extensions).

### Maintenance & Migration
*   **Schema Upgrades**: `Settings.upgrade` contains version-specific logic to migrate old configuration formats to new ones, ensuring backward compatibility across versions.
*   **Portability**: The Export/Import system uses a versioned JSON format, enabling users to move settings between different browsers or script instances easily.
