# coffeelint: disable=max_line_length
# coffeelint: disable=max_line_length
# Store domains per tab in chrome.storage.local
# Using a prefix to avoid conflicts with other storage keys
TAB_DOMAINS_STORAGE_PREFIX = "tabDomains_"

chrome.webRequest.onCompleted.addListener (details) ->
  # Only process requests for valid tabs and http/https schemes
  if details.tabId == -1 or not details.url.startsWith('http')
    return

  url = new URL(details.url)
  domain = url.hostname
  tabId = details.tabId
  storageKey = "#{TAB_DOMAINS_STORAGE_PREFIX}#{tabId}"

  chrome.storage.local.get storageKey, (data) ->
    domains = data[storageKey] || []

    # Add the domain if it's not already in the list for this tab
    unless domains.includes(domain)
      domains.push(domain)
      chrome.storage.local.set { [storageKey]: domains }, () ->
        console.log "Background: Added domain #{domain} to tab #{tabId}. Domains for tab #{tabId}:", domains

, { urls: ["<all_urls>"] }

# Clean up domains when a tab is closed
chrome.tabs.onRemoved.addListener (tabId, removeInfo) ->
  storageKey = "#{TAB_DOMAINS_STORAGE_PREFIX}#{tabId}"
  chrome.storage.local.remove storageKey, () ->
    console.log "Background: Cleaned up domains for closed tab #{tabId} from storage"

# Clear domains for a tab when the main frame navigates
chrome.tabs.onUpdated.addListener (tabId, changeInfo, tab) ->
  # Check if the update is a main frame navigation and the URL has changed
  if changeInfo.url and changeInfo.status == 'loading' and tab.active
    storageKey = "#{TAB_DOMAINS_STORAGE_PREFIX}#{tabId}"
    chrome.storage.local.remove storageKey, () ->
      console.log "Background: Cleared domains for tab #{tabId} on navigation to #{changeInfo.url}"


# Listen for messages from the popup script
chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
  console.log "Background: Received message:", request
  if request.action == "getTabDomains"
    tabId = request.tabId
    storageKey = "#{TAB_DOMAINS_STORAGE_PREFIX}#{tabId}"
    chrome.storage.local.get storageKey, (data) ->
      domains = data[storageKey] || []
      console.log "Background: Sending domains for tab #{tabId}:", domains
      sendResponse { domains: domains }
    # Return true to indicate that sendResponse will be called asynchronously
    true
  else if request.action == "clearTabDomains"
    tabId = request.tabId
    storageKey = "#{TAB_DOMAINS_STORAGE_PREFIX}#{tabId}"
    chrome.storage.local.remove storageKey, () ->
      console.log "Background: Cleared domains for tab #{tabId} from storage via clear button."
      sendResponse { status: "cleared" }
    # Return true to indicate that sendResponse will be called asynchronously
    true

# Fetch available models at launch and store them
# Function to fetch available models and store them
fetchAndStoreModels = () ->
  chrome.storage.local.get 'geminiApiKey', (data) ->
    apiKey = data.geminiApiKey
    if apiKey
      fetch("https://generativelanguage.googleapis.com/v1/models?key=#{apiKey}")
        .then (response) -> response.json()
        .then (data) ->
          if data.models
            # Filter models to only include gemini models
            geminiModels = data.models.filter (model) ->
              model.name.startsWith("models/gemini-")

            # Sort models by version number, highest first
            sortedModels = geminiModels.sort (a, b) ->
              getVersion = (modelName) ->
                try
                  # Extract version string (e.g., "1.5" from "models/gemini-pro-1.5")
                  versionString = modelName.split('/').pop().split('-').pop()
                  # Parse version parts into numbers (e.g., "1.5" -> [1, 5])
                  versionString.split('.').map(Number)
                catch
                  # Handle cases where version cannot be extracted
                  [0] # Treat as version 0 for sorting purposes

              versionA = getVersion(a.name)
              versionB = getVersion(b.name)

              # Compare version parts numerically
              maxLength = Math.max(versionA.length, versionB.length)
              for i in [0...maxLength]
                partA = versionA[i] || 0
                partB = versionB[i] || 0
                if partB != partA
                  return partB - partA # Sort descending

              0 # Versions are equal
            chrome.storage.local.set { availableModels: sortedModels }
            console.log "Background: Available models fetched, filtered, and stored:", sortedModels.map (m) -> m.name
          else
            console.error "Background: Error fetching models: No models array in response", data
        .catch (err) ->
          console.error "Background: Error fetching available models:", err
    else
      console.warn "Background: Gemini API key not set. Cannot fetch available models."

# Fetch available models when the background script starts
fetchAndStoreModels()
