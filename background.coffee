# coffeelint: disable=max_line_length

# --- Constants for Log Storage ---
LOG_STORAGE_KEY = "extension_historical_logs"
# Default MAX_LOG_ENTRIES, will be updated by loadMaxLogEntriesConfig
MAX_LOG_ENTRIES = 200
SCRIPT_NAME = "background"

# --- Original Console Functions (capture them before overriding) ---
originalConsoleLog = console.log
originalConsoleWarn = console.warn
originalConsoleError = console.error

# --- Helper for Stringifying Log Arguments ---
stringifyArgForStorage = (arg) ->
  if arg is null then "null"
  else if typeof arg is 'undefined' then "undefined"
  else if typeof arg is 'object' or Array.isArray(arg)
    try
      return JSON.stringify(arg, null, 2)
    catch e
      if arg.toString then return arg.toString()
      else return "[Unserializable Object]"
  else
    return String(arg)

# --- Function to Store Log Entries ---
storeLogEntry = (level, argsArray) ->
  formattedMessage = argsArray.map(stringifyArgForStorage).join(' ')
  logEntry =
    timestamp: Date.now()
    script: SCRIPT_NAME
    level: level
    message: formattedMessage

  chrome.storage.local.get [LOG_STORAGE_KEY], (data) ->
    if chrome.runtime.lastError
      originalConsoleError?.call(console, "#{SCRIPT_NAME}: Error retrieving logs for storage:", chrome.runtime.lastError.message)
      return

    logs = data[LOG_STORAGE_KEY] || []
    logs.push(logEntry)

    # Use the global MAX_LOG_ENTRIES which might have been updated from storage
    if logs.length > MAX_LOG_ENTRIES
      logs = logs.slice(-MAX_LOG_ENTRIES)

    chrome.storage.local.set { [LOG_STORAGE_KEY]: logs }, () ->
      if chrome.runtime.lastError
        originalConsoleError?.call(console, "#{SCRIPT_NAME}: Error saving new log entry:", chrome.runtime.lastError.message)

# --- Console Overrides ---
console.log = (...args) ->
  originalConsoleLog.apply(console, args)
  storeLogEntry('log', args)

console.warn = (...args) ->
  originalConsoleWarn.apply(console, args)
  storeLogEntry('warn', args)

console.error = (...args) ->
  originalConsoleError.apply(console, args)
  storeLogEntry('error', args)

# --- Existing Code Starts Below ---
TAB_DOMAINS_STORAGE_PREFIX = "tabDomains_"

chrome.webRequest.onCompleted.addListener (details) ->
  if details.tabId == -1 or not details.url.startsWith('http')
    return
  url = new URL(details.url)
  domain = url.hostname
  tabId = details.tabId
  storageKey = "#{TAB_DOMAINS_STORAGE_PREFIX}#{tabId}"
  chrome.storage.local.get storageKey, (data) ->
    domains = data[storageKey] || []
    unless domains.includes(domain)
      domains.push(domain)
      chrome.storage.local.set { [storageKey]: domains }, () ->
        chrome.tabs.query { active: true, currentWindow: true }, (tabs) ->
          if tabs and tabs[0]
            activeTab = tabs[0]
            if activeTab.id == tabId
              console.log "Background: Active tab matches request tab (#{tabId}). Sending updatePopupDomains message with domains:", domains
              chrome.runtime.sendMessage { action: "updatePopupDomains", tabId: tabId, domains: domains }, () ->
                if chrome.runtime.lastError then null # Suppress error
          else
            console.warn "Background: Could not determine active tab. No popup message sent for new domain in tab #{tabId}."
, { urls: ["<all_urls>"] }

chrome.tabs.onRemoved.addListener (tabId, removeInfo) ->
  storageKey = "#{TAB_DOMAINS_STORAGE_PREFIX}#{tabId}"
  chrome.storage.local.remove storageKey, () ->
    console.log "Background: Cleaned up domains for closed tab #{tabId} from storage"

chrome.tabs.onUpdated.addListener (tabId, changeInfo, tab) ->
  if changeInfo.status == 'loading' and changeInfo.url
    storageKey = "#{TAB_DOMAINS_STORAGE_PREFIX}#{tabId}"
    chrome.storage.local.remove storageKey, () ->
      console.log "Background: Tab #{tabId} navigated to new URL (#{changeInfo.url}). Cleared its domains."
      chrome.runtime.sendMessage { action: "updatePopupDomains", tabId: tabId, domains: [] }, () ->
        if chrome.runtime.lastError then null

chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
  console.log "Background: Received message:", request
  if request.action == "getTabDomains"
    tabId = request.tabId
    storageKey = "#{TAB_DOMAINS_STORAGE_PREFIX}#{tabId}"
    chrome.storage.local.get storageKey, (data) ->
      domains = data[storageKey] || []
      console.log "Background: Sending domains for tab #{tabId}:", domains
      sendResponse { domains: domains }
    true
  else if request.action == "clearTabDomains"
    tabId = request.tabId
    storageKey = "#{TAB_DOMAINS_STORAGE_PREFIX}#{tabId}"
    chrome.storage.local.remove storageKey, () ->
      console.log "Background: Cleared domains for tab #{tabId} from storage via clear button."
      sendResponse { status: "cleared" }
    true

getGeminiSortScore = (modelNameWithPrefix) ->
  name = modelNameWithPrefix.replace("models/", "").toLowerCase()
  score = 5000; version = 0.0; versionStr = "0.0"; modelType = "unknown"; isLatest = false; hasNumericSuffix = false
  versionMatch = name.match(/gemini-([0-9]\.[0-9]+)/)
  if versionMatch and versionMatch[1]
    version = parseFloat(versionMatch[1]); versionStr = versionMatch[1]
  else if name.includes("gemini-1.5")
    version = 1.5; versionStr = "1.5"
  else if name.includes("gemini-1.0") or name.includes("gemini-pro-vision") or name.includes("gemini-pro")
    version = 1.0; versionStr = "1.0"
    if name.includes("gemini-pro-vision") then versionStr = "1.0 (vision)"
    else if name == "gemini-pro" then versionStr = "1.0 (legacy pro)"
  score -= version * 1000
  if name.includes("pro") then score -= 100; modelType = "pro"
  else if name.includes("flash") then score -= 50; modelType = "flash"
  if name.includes("latest") then score -= 20; isLatest = true
  if name.match(/-[0-9]{3}$/) then score += 5; hasNumericSuffix = true
  console.log "GeminiSortScore: FullName: '#{modelNameWithPrefix}', ParsedName: '#{name}', Version: #{versionStr}, Type: #{modelType}, Latest: #{isLatest}, NumSuffix: #{hasNumericSuffix} => Score: #{score}"
  return score

getGroqSortScore = (modelId) ->
  id = modelId.toLowerCase()
  if id.includes("mixtral-8x7b") then return 1
  if id.includes("llama2-70b") then return 2
  if id.includes("llama3-70b") then return 3
  if id.includes("llama3-8b") then return 5
  if id.includes("llama2-13b") then return 10
  if id.includes("llama") then return 15
  if id.includes("gemma-7b") then return 20
  if id.includes("gemma-2b") then return 22
  if id.includes("gemma") then return 25
  return 100

fetchAndStoreModels = () ->
  chrome.storage.local.get ['geminiApiKey', 'groqApiKey'], (data) ->
    geminiApiKey = data.geminiApiKey; groqApiKey = data.groqApiKey
    fetchGeminiModels = () ->
      new Promise (resolve, reject) ->
        if geminiApiKey
          fetch("https://generativelanguage.googleapis.com/v1/models?key=#{geminiApiKey}")
            .then (response) -> response.json()
            .then (data) ->
              if data.models
                geminiModels = data.models.filter (model) -> model.name.startsWith("models/gemini-")
                console.log "Background: Fetched Gemini models:", geminiModels.map (m) -> m.name
                resolve geminiModels
              else
                console.error "Background: Error fetching Gemini models: No models array in response", data
                resolve []
            .catch (err) -> console.error "Background: Error fetching Gemini available models:", err; resolve []
        else console.warn "Background: Gemini API key not set."; resolve []
    fetchGroqModels = () ->
      new Promise (resolve, reject) ->
        if groqApiKey
          fetch("https://api.groq.com/openai/v1/models?free=true", headers: { 'Authorization': "Bearer #{groqApiKey}" })
            .then (response) -> response.json()
            .then (data) ->
              if data.data
                groqModels = data.data
                console.log "Background: Fetched Groq models:", groqModels.map (m) -> m.id
                resolve groqModels
              else
                console.error "Background: Error fetching Groq models: No data array in response", data
                resolve []
            .catch (err) -> console.error "Background: Error fetching Groq available models:", err; resolve []
        else console.warn "Background: Groq API key not set."; resolve []
    Promise.all([fetchGeminiModels(), fetchGroqModels()])
      .then (([rawGeminiModels, rawGroqModels]) ->
        sortedGeminiModels = rawGeminiModels.sort (a, b) -> getGeminiSortScore(a.name) - getGeminiSortScore(b.name) or a.name.localeCompare(b.name)
        console.log "Background: Sorted Gemini Models (scores applied):", sortedGeminiModels.map (m) -> {name: m.name, finalScore: getGeminiSortScore(m.name)}
        sortedGroqModels = rawGroqModels.sort (a, b) ->
          scoreA = getGroqSortScore(a.id); scoreB = getGroqSortScore(b.id)
          if scoreA == scoreB then return a.id.localeCompare(b.id)
          return scoreA - scoreB
        console.log "Background: Sorted Groq Models (scores applied):", sortedGroqModels.map (m) -> {id: m.id, score: getGroqSortScore(m.id)}
        allSortedModels = sortedGeminiModels.concat(sortedGroqModels)
        chrome.storage.local.set { availableModels: allSortedModels }, () ->
          console.log "Background: All available models fetched, sorted heuristically, and stored:", allSortedModels.map (m) -> m.name ? m.id
      )
      .catch (err) -> console.error "Background: Error combining, sorting, or storing models:", err

fetchAndStoreModels() # Initial fetch

# --- MAX_LOG_ENTRIES Configuration Loading and Update ---
loadMaxLogEntriesConfig = () ->
  chrome.storage.local.get ['maxLogEntriesConfig'], (data) ->
    if chrome.runtime.lastError
      console.error "Background: Error loading maxLogEntriesConfig:", chrome.runtime.lastError.message
      return
    if data.maxLogEntriesConfig isnt undefined
      parsedValue = parseInt(data.maxLogEntriesConfig, 10)
      if not isNaN(parsedValue) and parsedValue >= 50 and parsedValue <= 1000
        console.log "Background: Loaded maxLogEntriesConfig from storage: #{parsedValue}"
        # MAX_LOG_ENTRIES is a global (to this script) const-like variable after initial declaration.
        # CoffeeScript doesn't have true const for reassignable variables like this after initialisation.
        # This will effectively change the limit for subsequent storeLogEntry calls.
        # For a true const, it would need to be an object property or handled differently.
        # Given the script structure, reassigning this top-level variable is the most straightforward.
        # This is a deviation from typical const behavior but acceptable for this script's scope.
        this.MAX_LOG_ENTRIES = parsedValue # Explicitly assign to script's context if needed, or direct if top-level
      else
        console.warn "Background: Loaded maxLogEntriesConfig (#{data.maxLogEntriesConfig}) is out of bounds [50-1000] or NaN. Using default #{MAX_LOG_ENTRIES}."
    else
      console.log "Background: No maxLogEntriesConfig found. Using default #{MAX_LOG_ENTRIES}."

loadMaxLogEntriesConfig() # Load config at startup

chrome.storage.onChanged.addListener (changes, areaName) ->
  if areaName == "local"
    apiKeyChanged = false
    for key, change of changes
      if key == "geminiApiKey" or key == "groqApiKey"
        apiKeyChanged = true
        break # No need to check further if one API key changed

    if apiKeyChanged
      console.log "Background: API key changed, re-fetching available models."
      fetchAndStoreModels()

    if changes.maxLogEntriesConfig
      newValue = changes.maxLogEntriesConfig.newValue
      if newValue isnt undefined
        parsedNewValue = parseInt(newValue, 10)
        if not isNaN(parsedNewValue) and parsedNewValue >= 50 and parsedNewValue <= 1000
          console.log "Background: maxLogEntriesConfig changed to: #{parsedNewValue}. Updating MAX_LOG_ENTRIES."
          this.MAX_LOG_ENTRIES = parsedNewValue # Update the global-like variable

          # Trim existing logs if necessary
          chrome.storage.local.get [LOG_STORAGE_KEY], (data) ->
            if chrome.runtime.lastError
              console.error "Background: Error retrieving logs for trimming:", chrome.runtime.lastError.message
              return
            if data[LOG_STORAGE_KEY]
              currentLogs = data[LOG_STORAGE_KEY]
              if currentLogs.length > this.MAX_LOG_ENTRIES # Use the updated value
                trimmedLogs = currentLogs.slice(-this.MAX_LOG_ENTRIES)
                chrome.storage.local.set { [LOG_STORAGE_KEY]: trimmedLogs }, () ->
                  if chrome.runtime.lastError
                    console.error "Background: Error saving trimmed logs:", chrome.runtime.lastError.message
                  else
                    console.log "Background: Historical logs trimmed to new MAX_LOG_ENTRIES limit of #{this.MAX_LOG_ENTRIES}."
        else
          console.warn "Background: Attempted change to maxLogEntriesConfig (#{newValue}) is invalid or out of bounds. Not applying."
      else
        console.warn "Background: Invalid change to maxLogEntriesConfig (undefined newValue). Not applying."
