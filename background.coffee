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

# Auto-clear domains on page navigation (main frame navigation)
chrome.tabs.onUpdated.addListener (tabId, changeInfo, tab) ->
  # Check if the update is for the main frame, status is 'loading', and a URL is present
  # changeInfo.url is present when the URL of the tab changes.
  if changeInfo.status == 'loading' and changeInfo.url
    storageKey = "#{TAB_DOMAINS_STORAGE_PREFIX}#{tabId}"
    chrome.storage.local.remove storageKey, () ->
      console.log "Background: Tab #{tabId} navigated to new URL (#{changeInfo.url}). Cleared its domains."
      # Send message to popup to clear its view for this tab
      chrome.runtime.sendMessage { action: "updatePopupDomains", tabId: tabId, domains: [] }, () ->
        if chrome.runtime.lastError
          # Expected if popup for this tab isn't open or ready
          null

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

# Helper function to assign sort scores to Gemini models
getGeminiSortScore = (modelName) ->
  score = 100 # Default large score for less preferred models
  name = modelName.toLowerCase()

  if name.includes("gemini-1.5")
    score -= 50
  else if name.includes("gemini-1.0")
    score -= 25 # Prefer 1.0 over unspecified or older if any

  if name.includes("pro")
    score -= 10
  else if name.includes("flash")
    score -= 5 # Pro is better than Flash

  if name.includes("latest")
    score -= 20 # 'latest' is highly preferred

  # Models like "gemini-pro" (older, less specific) will get higher scores (less preferred)
  # compared to "gemini-1.0-pro"
  if name == "models/gemini-pro" # This is often an alias for an older 1.0 model
      score = 60 # Make it less preferred than explicit 1.0 pro or any 1.5

  return score

# Helper function to assign sort scores to Groq models
getGroqSortScore = (modelId) ->
  id = modelId.toLowerCase()
  # Prioritize by model family and size (lower score is better)
  if id.includes("mixtral-8x7b") then return 1
  if id.includes("llama2-70b") then return 2
  if id.includes("llama3-70b") then return 3 # Assuming llama3 is newer/better
  if id.includes("llama3-8b") then return 5
  if id.includes("llama2-13b") then return 10
  if id.includes("llama") then return 15 # Generic llama catch-all
  if id.includes("gemma-7b") then return 20
  if id.includes("gemma-2b") then return 22
  if id.includes("gemma") then return 25 # Generic gemma
  return 100 # Default for others

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
      .then ([rawGeminiModels, rawGroqModels]) -> # Renamed to raw to signify they are unsorted

        # Sort Gemini Models
        # The filter for "models/gemini-" is already done in fetchGeminiModels
        sortedGeminiModels = rawGeminiModels.sort (a, b) ->
          scoreA = getGeminiSortScore(a.name)
          scoreB = getGeminiSortScore(b.name)
          if scoreA == scoreB
            # Fallback to alphabetical for same score
            return a.name.localeCompare(b.name)
          return scoreA - scoreB

        console.log "Background: Sorted Gemini Models (scores applied):", sortedGeminiModels.map (m) -> {name: m.name, score: getGeminiSortScore(m.name)}

        # Sort Groq Models
        # Groq models are already filtered in fetchGroqModels if needed
        sortedGroqModels = rawGroqModels.sort (a, b) ->
          scoreA = getGroqSortScore(a.id)
          scoreB = getGroqSortScore(b.id)
          if scoreA == scoreB
            # Fallback to alphabetical for same score
            return a.id.localeCompare(b.id)
          return scoreA - scoreB

        console.log "Background: Sorted Groq Models (scores applied):", sortedGroqModels.map (m) -> {id: m.id, score: getGroqSortScore(m.id)}

        # Combine sorted models, Gemini first
        allSortedModels = sortedGeminiModels.concat(sortedGroqModels)

        chrome.storage.local.set { availableModels: allSortedModels }, () ->
          console.log "Background: All available models fetched, sorted heuristically, and stored:", allSortedModels.map (m) -> m.name ? m.id
      .catch (err) ->
        console.error "Background: Error combining, sorting, or storing models:", err

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
