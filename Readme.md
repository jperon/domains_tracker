# Network Address Collector

Browser extension to collect domains contacted by each tab and obtain AI-generated descriptions for these domains.

## Features

- **Per-Tab Domain Collection**: Records domains accessed by each browser tab.
- **AI-Powered Descriptions**: Leverages Gemini or Groq APIs to generate concise descriptions and safety classifications (e.g., necessary, useful, advertising, tracking) for each domain.
- **Intuitive Popup Interface**: Displays collected domains for the active tab, along with their AI-generated details. Features include copying domains, clearing the list, viewing raw API responses, and accessing console logs.
- **Configurable Options Page**: Allows users to securely input and manage their API keys for Gemini and Groq.
- **Smart API Key Handling**: Utilizes configured API keys and prompts for setup if a key is missing.
- **Efficient Caching**: Stores AI-generated descriptions locally to minimize redundant API calls for previously analyzed domains within the active tab.

## Project Structure

The project root directory contains all source files, configuration files, assets, and build outputs.
```
network-address-collector/
├── manifest.yaml          # Source: Main extension configuration (YAML, primarily for Chrome)
├── firefox-manifest.yaml  # Source: Firefox-specific manifest configuration (YAML)
├── background.coffee      # Source: Core background script for domain collection
├── popup.pug             # Source: HTML template for the extension popup's UI
├── popup.coffee          # Source: Client-side logic for the extension popup
├── options.pug           # Source: HTML template for the extension's options page UI
├── options.coffee        # Source: Client-side logic for the options page
├── content.coffee        # Source: Script for interacting with web page content (if applicable)
├── styles.css            # Source: CSS styles for the popup and options pages
├── icon.png              # Asset: The extension's icon displayed in the browser
├── package.json          # Defines NPM dependencies, and scripts (build, watch, etc.)
├── LICENSE.md            # Contains the software license for the project
├── .gitignore            # Specifies files and directories ignored by Git
└── README.md             # This file: Overview and instructions for the project

# After `npm run build`, the following compiled/transpiled files are typically generated in the root directory:
├── manifest.json         # Output: Standard JSON manifest (e.g., for Chrome or generated from firefox-manifest.yaml)
├── background.js         # Output: Transpiled JavaScript for the background script
├── popup.html            # Output: HTML file for the popup
├── popup.js              # Output: Transpiled JavaScript for the popup logic
├── options.html          # Output: HTML file for the options page
├── options.js            # Output: Transpiled JavaScript for the options page logic
└── content.js            # Output: Transpiled JavaScript for the content script (if applicable)
# Note: The exact output can depend on the build scripts in package.json, especially for multiple browser targets.
```

## Installation

### 1. Prerequisites

- Ensure Node.js is installed on your system. You can download it from [nodejs.org](https://nodejs.org/).

### 2. Install Project Dependencies

Open your terminal, navigate to the project's root directory, and execute the following command:
This command reads the `package.json` file and installs all necessary development dependencies (e.g., CoffeeScript, Pug, js-yaml transpilers) locally within the project.

```bash
npm install
```

### 3. Build the Extension

Once dependencies are installed, compile the source files by running:
This command executes the `build` script defined in `package.json`. It transpiles CoffeeScript files to JavaScript, Pug files to HTML, and YAML manifest files to JSON. The resulting output files are placed in the **root directory** and are ready for the browser.

For ongoing development, `npm run watch` can be used to automatically recompile files when changes are detected. The `npm run clean` script can be used to remove generated files.

```bash
# Full build (compiles all necessary files into the root directory)
npm run build

# Optional: Watch mode (monitors changes and recompiles automatically)
# npm run watch

# Optional: Clean generated files
# npm run clean
```

### 4. Load the Extension in Your Browser

Once the build process is complete (`npm run build`), the **root project directory** will contain all the necessary files for the extension to run, including the crucial `manifest.json` file.

**Chrome/Chromium:**

1.  Navigate to `chrome://extensions/`.
2.  Enable "Developer mode" (usually a toggle in the top right).
3.  Click on "Load unpacked".
4.  Select the **root project directory**.

**Firefox:**

1.  Navigate to `about:debugging#/runtime/this-firefox`.
2.  Click on "Load Temporary Add-on...".
3.  Select the `manifest.json` file located in the **root project directory**.

## Usage

### Automatic Collection

The extension starts collecting automatically upon installation:

1. **Normal Browsing**: Browse as usual.
2. **Transparent Collection**: Domains are recorded in the background for the active tab.
3. **Minimal Performance Impact**: Asynchronous background processing.

### User Interface

Click the extension's icon in your browser toolbar to open the popup interface:

- **Domain List**: View domains contacted by the currently active tab.
- **AI Insights**: See AI-generated descriptions and classifications for external domains (if API keys are configured).
- **Selection**: Use checkboxes to select specific domains.
- **Copy**: Copies the selected domains to your clipboard.
- **Clear**: Erases the collected domain list for the active tab.
- **Toggle JSON**: Shows or hides the raw JSON response from the AI API for troubleshooting.
- **Toggle Console**: Displays or hides any console log output within the popup for debugging.

## Automatic Management

The extension automatically manages:

- **Deduplication**: Prevents duplicate domains in the list for a tab.
- **Cleanup**: Removes collected domains for a tab when that tab is closed.

## Security and Privacy

### Collected Data

- **Domain-Level Collection**: The extension only records domain names (e.g., `example.com`), not full URLs or any content from visited pages.
- **No Page Content Stored**: Absolutely no data from the web pages you visit is collected or stored.
- **AI Interaction**: If an API key is configured and the popup is opened, the extension sends only the list of *external* domains from the active tab to your chosen AI provider (Gemini or Groq). The AI is prompted to return a brief explanation and classification for each domain. This communication is directly between your browser and the AI provider.
- **Local Browser Storage**: All collected domain data and AI-generated descriptions are stored locally on your computer using the browser's standard storage mechanisms. This data is not transmitted to any external servers by the extension itself.
- **Automatic Data Purge**: When a browser tab is closed, all domain data collected specifically for that tab is automatically deleted from your computer's local storage.

### Required Permissions Explained
- `webRequest`: Essential for intercepting network requests to identify the domains being contacted.
- `storage`: Required for the local storage of collected domain lists, AI-generated descriptions, and user-configured settings (like API keys).
- `activeTab`: Allows the extension to interact with the currently active tab, primarily to display its specific domain list when the popup is opened.
- `<all_urls>`: Necessary for the `webRequest` permission to function across all websites. This permission is used in a read-only capacity to analyze network requests; the extension does not read or alter content from any web page.

## Development Notes

### Core Architecture
- **Manifest V3 Compliance**: Developed according to the latest browser extension standards (Manifest V3), emphasizing security, privacy, and performance.
- **Service Worker (`background.js`)**: Network request monitoring and domain logging are managed by a background service worker, ensuring continuous operation without direct user interface.
- **Local Storage (`storage` API)**: All persistent data, such as collected domains and user preferences, is stored locally and securely using the browser's built-in storage API.
- **Network Interception (`webRequest` API)**: The extension uses the `webRequest` API to observe outgoing network requests and identify unique domain interactions.

## License

MIT License - Free to use and modify.
```
