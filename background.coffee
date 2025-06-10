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
        # console.log "Background: Added domain #{domain} to tab #{tabId}. Domains for tab #{tabId}:", domains # Reduced verbosity
        # Check if the updated tab is the active one and send a message to its popup
        chrome.tabs.query { active: true, currentWindow: true }, (tabs) ->
          if tabs and tabs[0]
            activeTab = tabs[0]
            # Only send the message if the web request's tab is the currently active tab
            if activeTab.id == tabId
              console.log "Background: Active tab matches request tab (#{tabId}). Sending updatePopupDomains message with domains:", domains
              chrome.runtime.sendMessage { action: "updatePopupDomains", tabId: tabId, domains: domains }, () ->
                if chrome.runtime.lastError
                  # This error is expected if the popup for the active tab is not open
                  # console.log "Background: Could not send updatePopupDomains message to active tab popup:", chrome.runtime.lastError.message
                  null # Suppress error logging
            # else
            #   console.log "Background: Domain #{domain} added to non-active tab #{tabId}. Active tab is #{activeTab.id}. No popup message sent."
          else
            console.warn "Background: Could not determine active tab. No popup message sent for new domain in tab #{tabId}."

, { urls: ["<all_urls>"] }

# Clean up domains when a tab is closed
chrome.tabs.onRemoved.addListener (tabId, removeInfo) ->
  storageKey = "#{TAB_DOMAINS_STORAGE_PREFIX}#{tabId}"
  chrome.storage.local.remove storageKey, () ->
    console.log "Background: Cleaned up domains for closed tab #{tabId} from storage"

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
  chrome.storage.local.get ['geminiApiKey', 'groqApiKey'], (data) ->
    geminiApiKey = data.geminiApiKey
    groqApiKey = data.groqApiKey
    allModels = []

    fetchGeminiModels = () ->
      new Promise (resolve, reject) ->
        if geminiApiKey
          fetch("https://generativelanguage.googleapis.com/v1/models?key=#{geminiApiKey}")
            .then (response) -> response.json()
            .then (data) ->
              if data.models
                # Filter models to only include gemini models
                geminiModels = data.models.filter (model) ->
                  model.name.startsWith("models/gemini-")
                console.log "Background: Fetched Gemini models:", geminiModels.map (m) -> m.name
                resolve geminiModels
              else
                console.error "Background: Error fetching Gemini models: No models array in response", data
                resolve [] # Resolve with empty array on error
            .catch (err) ->
              console.error "Background: Error fetching Gemini available models:", err
              resolve [] # Resolve with empty array on error
        else
          console.warn "Background: Gemini API key not set. Skipping Gemini model fetch."
          resolve [] # Resolve with empty array if no key

    fetchGroqModels = () ->
      new Promise (resolve, reject) ->
        if groqApiKey
          fetch("https://api.groq.com/openai/v1/models?free=true",
            headers:
              'Authorization': "Bearer #{groqApiKey}"
          )
            .then (response) -> response.json()
            .then (data) ->
              if data.data # Groq API returns models in a 'data' array
                # Groq API already filters for free=true, no extra filtering needed here
                groqModels = data.data
                console.log "Background: Fetched Groq models:", groqModels.map (m) -> m.id
                resolve groqModels
              else
                console.error "Background: Error fetching Groq models: No data array in response", data
                resolve [] # Resolve with empty array on error
            .catch (err) ->
              console.error "Background: Error fetching Groq available models:", err
              resolve [] # Resolve with empty array on error
        else
          console.warn "Background: Groq API key not set. Skipping Groq model fetch."
          resolve [] # Resolve with empty array if no key

    # Fetch models from both APIs concurrently
    Promise.all([fetchGeminiModels(), fetchGroqModels()])
      .then ([geminiModels, groqModels]) ->
        # Combine models from both APIs
        allModels = geminiModels.concat(groqModels)

        # Sort models (optional, but good for consistency - can refine sorting later if needed)
        # For now, a simple sort by name/id
        sortedModels = allModels.sort (a, b) ->
          nameA = a.name ? a.id # Use name for Gemini, id for Groq
          nameB = b.name ? b.id
          nameA.localeCompare(nameB)

        chrome.storage.local.set { availableModels: sortedModels }, () ->
          console.log "Background: All available models fetched and stored:", sortedModels.map (m) -> m.name ? m.id
      .catch (err) ->
        console.error "Background: Error combining or storing models:", err

# Fetch available models when the background script starts
fetchAndStoreModels()

# Listen for changes in storage (e.g., API keys updated in options)
chrome.storage.onChanged.addListener (changes, areaName) ->
  if areaName == "local"
    apiKeyChanged = false
    for key, change of changes
      if key == "geminiApiKey" or key == "groqApiKey"
        apiKeyChanged = true
        break

    if apiKeyChanged
      console.log "Background: API key changed, re-fetching available models."
      fetchAndStoreModels()
