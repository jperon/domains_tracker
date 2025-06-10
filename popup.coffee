# Redirect console messages to a div
originalConsoleLog = console.log
originalConsoleWarn = console.warn
originalConsoleError = console.error

# Helper function to stringify arguments for custom console
stringifyArg = (arg) ->
  if arg is null then "null"
  else if typeof arg is 'undefined' then "undefined"
  else if typeof arg is 'object' or Array.isArray(arg)
    try
      return JSON.stringify(arg, null, 2) # Pretty print objects/arrays
    catch e
      # Handle circular references or other stringify errors
      if arg.toString then return arg.toString() # Standard [object Object] or array content
      else return "[Unserializable Object]"
  else
    return String(arg) # Ensure it's a string

appendConsoleMessage = (formattedMessage, level = 'log') ->
  consoleOutputDiv = document.getElementById 'console-output'
  if consoleOutputDiv
    messageElement = document.createElement 'div'
    messageElement.style.whiteSpace = 'pre-wrap' # Allow multi-line and preserve spaces
    messageElement.textContent = formattedMessage # Message is now pre-formatted
    messageElement.classList.add "console-#{level}" # For potential CSS styling
    consoleOutputDiv.appendChild messageElement
    consoleOutputDiv.scrollTop = consoleOutputDiv.scrollHeight # Auto-scroll

console.log = ->
  args = Array.from(arguments)
  processedMessages = args.map (arg) -> stringifyArg(arg)
  fullMessage = processedMessages.join(' ')
  appendConsoleMessage("Popup: LOG: " + fullMessage, 'log')
  originalConsoleLog.apply(console, arguments) # Call original for browser console

console.warn = ->
  args = Array.from(arguments)
  processedMessages = args.map (arg) -> stringifyArg(arg)
  fullMessage = processedMessages.join(' ')
  appendConsoleMessage("Popup: WARN: " + fullMessage, 'warn')
  originalConsoleWarn.apply(console, arguments)

console.error = ->
  args = Array.from(arguments)
  processedMessages = args.map (arg) -> stringifyArg(arg)
  fullMessage = processedMessages.join(' ')
  appendConsoleMessage("Popup: ERROR: " + fullMessage, 'error')
  originalConsoleError.apply(console, arguments)

# coffeelint: disable=max_line_length
# Constants for Groq API
GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions"

# Utility function to parse JSON from AI response text
parseAIResponseJSON = (responseText) ->
  if not responseText or typeof responseText isnt 'string'
    throw new Error("Invalid response text provided for parsing.")
  startIndex = responseText.indexOf('{')
  endIndex = responseText.lastIndexOf('}')
  if startIndex != -1 and endIndex != -1 and endIndex > startIndex
    jsonString = responseText.substring(startIndex, endIndex + 1)
    try
      return JSON.parse(jsonString)
    catch e
      # console.error "Popup: JSON.parse failed for string:", jsonString, "Error:", e # Already logged by console.error override
      throw new Error("Failed to parse JSON from response text. #{e.message}")
  else
    throw new Error("Could not find valid JSON object delimiters in response text.")

# Utility function to call the Gemini API
callGeminiApi = (modelName, apiKey, promptText) ->
  fetch("https://generativelanguage.googleapis.com/v1/models/#{modelName.split('/').pop()}:generateContent?key=#{apiKey}",
    method: 'POST'
    headers: { 'Content-Type': 'application/json' }
    body: JSON.stringify(
      contents: [ parts: [ {text: promptText} ] ],
      generationConfig: { maxOutputTokens: 20000, temperature: 0.0 }
    )
  )
  .then (response) ->
    if response.ok then response.json()
    else response.text().then (text) -> throw new Error("HTTP error! status: #{response.status}, body: #{text}")

# Utility function to update the domain list with descriptions
updateDomainListWithDescriptions = (descriptions, domainListElement) ->
  briefOrder = ['necessary', 'useful', 'optional', 'ad', 'tracking', 'dangerous']
  domainArray = []
  for domain, domainInfo of descriptions
    domainArray.push { domain: domain, domainInfo: domainInfo }
  domainArray.sort (a, b) ->
    briefA = a.domainInfo.brief ? ''; briefB = b.domainInfo.brief ? ''
    indexA = briefOrder.indexOf(briefA); indexB = briefOrder.indexOf(briefB)
    if indexA == -1 and indexB == -1 then 0
    else if indexA == -1 then 1
    else if indexB == -1 then -1
    else indexA - indexB
  domainListElement.innerHTML = ''
  for domainObj in domainArray
    domain = domainObj.domain; domainInfo = domainObj.domainInfo
    li = document.createElement 'li'
    checkbox = document.createElement 'input'; checkbox.type = 'checkbox'
    if domainInfo.brief in ['necessary', 'useful'] then checkbox.checked = true
    li.appendChild checkbox
    domainStrong = document.createElement 'strong'; domainStrong.textContent = domain
    li.appendChild domainStrong
    descriptionText = ""; briefClass = ""
    if domainInfo.brief
      if domainInfo.brief in ['necessary', 'useful'] then briefClass = 'brief-green'
      else if domainInfo.brief in ['ad', 'tracking', 'dangerous'] then briefClass = 'brief-red'
      descriptionText = " - <span class=\"#{briefClass}\">#{domainInfo.brief}</span>:<br/> #{domainInfo.why}"
    else if domainInfo.why
      descriptionText = " - #{domainInfo.why}"
    descriptionSpan = document.createElement 'span'; descriptionSpan.innerHTML = descriptionText
    li.appendChild descriptionSpan
    domainListElement.appendChild li

# Utility function to call the Groq API
callGroqApi = (modelName, apiKey, promptText) ->
  fetch(GROQ_API_URL,
    method: 'POST'
    headers: { 'Content-Type': 'application/json', 'Authorization': "Bearer #{apiKey}" }
    body: JSON.stringify(
      messages: [ { role: "user", content: promptText } ],
      model: modelName, temperature: 0, max_completion_tokens: 1024, top_p: 1, stream: false, stop: null
    )
  )
  .then (response) ->
    if response.ok then response.json()
    else response.text().then (text) -> throw new Error("HTTP error! status: #{response.status}, body: #{text}")
  .catch (err) ->
    console.error "Popup: Fetch error in callGroqApi for model #{modelName}:", err # Will be formatted
    throw err

# Utility function to determine API configuration
determineApiConfig = (availableModels, manageStatusFunc) ->
  new Promise (resolve, reject) ->
    chrome.storage.local.get ['geminiApiKey', 'groqApiKey'], (data) ->
      if chrome.runtime.lastError then return reject(chrome.runtime.lastError)
      geminiApiKey = data.geminiApiKey; groqApiKey = data.groqApiKey
      apiTypeToUse = null; apiKeyToUse = null; modelsToUse = []
      if geminiApiKey
        apiTypeToUse = 'gemini'; apiKeyToUse = geminiApiKey
        if availableModels and availableModels.length > 0
          modelsToUse = availableModels.filter((m) -> m?.name?.includes('gemini')).map((m) -> m.name)
      else if groqApiKey
        apiTypeToUse = 'groq'; apiKeyToUse = groqApiKey
        if availableModels and availableModels.length > 0
          modelsToUse = availableModels.filter((m) -> m?.object == 'model' and m.id?).map((m) -> m.id)

      if not apiKeyToUse
        fallbackMessageDiv = document.getElementById 'fallback-key-message'
        if fallbackMessageDiv # Try to use specific div for this message
          fallbackMessageDiv.innerHTML = "<strong><span style=\"color: orange;\">Please add your API key on the <a href=\"options.html\" target=\"_blank\">options page</a>.</span></strong>"
          fallbackMessageDiv.style.display = 'block'
          manageStatusFunc("", 'info') # Clear generic status message if specific one is shown
        else # Fallback to generic status message
          manageStatusFunc("Please add your API key on the <a href=\"options.html\" target=\"_blank\">options page</a>. (HTML will not render here)", 'warn')
        resolve { apiTypeToUse: null, apiKeyToUse: null, modelsToUse: [] }
      else
        modelsToUse = modelsToUse.filter (model) -> model?
        resolve { apiTypeToUse, apiKeyToUse, modelsToUse }

document.addEventListener 'DOMContentLoaded', () ->
  console.log "Popup: DOMContentLoaded event fired. Initializing popup script."
  domainListEl = document.getElementById 'domain-list'
  clearButton = document.getElementById 'clear-button'
  showJsonButton = document.getElementById 'show-json-button'
  jsonResponseDiv = document.getElementById 'json-response'
  showConsoleButton = document.getElementById 'show-console-button'
  # consoleOutputDiv is handled by appendConsoleMessage directly
  statusMessageEl = document.getElementById 'status-message'
  copyDomainsButton = document.getElementById 'copy-domains-button'
  fallbackMessageDiv = document.getElementById 'fallback-key-message'

  let localLastApiResponse = null
  let localDomainDescriptions = {}
  let statusMessageTimeoutId = null

  manageStatusMessage = (messageText, type = 'info', duration = null) ->
    if statusMessageEl
      # If messageText is intended to be HTML, this needs to be innerHTML
      # For now, assuming messageText from new console overrides is pre-formatted string
      statusMessageEl.textContent = messageText
      if type == 'error' then statusMessageEl.style.color = 'red'
      else if type == 'warn' then statusMessageEl.style.color = 'orange'
      else statusMessageEl.style.color = 'black'

      if messageText == "" or messageText == null
        statusMessageEl.style.display = 'none'
      else
        statusMessageEl.style.display = 'block'
        # If specific fallback message is showing, and this is a new status, hide fallback
        if fallbackMessageDiv and fallbackMessageDiv.style.display == 'block' and messageText isnt fallbackMessageDiv.textContent
          fallbackMessageDiv.style.display = 'none'


      if statusMessageTimeoutId then clearTimeout(statusMessageTimeoutId)
      statusMessageTimeoutId = null
      if duration and typeof duration == 'number'
        statusMessageTimeoutId = setTimeout (() ->
          statusMessageEl.style.display = 'none'
          statusMessageEl.textContent = ''
        ), duration
    # else originalConsoleError("Status message element not found in manageStatusMessage") # Avoid using overridden console.error

  handleApiResponse = (info, apiType, domainsToQuery, mainDomain) ->
    localLastApiResponse = info
    descriptionText = null
    if apiType == 'gemini' then descriptionText = info?.candidates?[0]?.content?.parts?[0]?.text
    else if apiType == 'groq' then descriptionText = info?.choices?[0]?.message?.content
    if descriptionText
      try
        descriptions = parseAIResponseJSON(descriptionText)
        localDomainDescriptions = descriptions
        chrome.storage.local.set { cachedDomains: domainsToQuery, cachedResponse: JSON.stringify(localLastApiResponse), cachedApiType: apiType }, () ->
          if chrome.runtime.lastError then console.error "Popup: Error saving cache:", chrome.runtime.lastError.message
        localDomainDescriptions[mainDomain] = { why: 'main domain', brief: 'necessary' }
        updateDomainListWithDescriptions(localDomainDescriptions, domainListEl)
        manageStatusMessage("Descriptions loaded.", 'success', 3000)
        return true
      catch e
        console.error "Popup: Failed to parse API response JSON:", e # Formatted
        manageStatusMessage("Error parsing AI response. Check console.", 'error', 5000) # User-friendly
        throw e
    else
      manageStatusMessage("Empty response from AI. Check console.", 'error', 5000) # User-friendly
      throw new Error("API response does not contain description text.")

  fetchAndDisplayDescriptions = (domains, mainDomain) ->
    chrome.storage.local.get ['availableModels', 'cachedDomains', 'cachedResponse', 'cachedApiType'], (storageData) ->
      availableModels = storageData.availableModels
      cachedDomains = storageData.cachedDomains
      cachedResponse = storageData.cachedResponse
      cachedApiType = storageData.cachedApiType
      domainsToQuery = domains.filter (domain) -> domain != mainDomain
      if domainsToQuery.length == 0
        if fallbackMessageDiv then fallbackMessageDiv.style.display = 'none'
        manageStatusMessage("", 'info')
        return
      determineApiConfig(availableModels, manageStatusMessage)
        .then (({ apiTypeToUse, apiKeyToUse, modelsToUse }) ->
          if not apiKeyToUse then return # manageStatusMessage called in determineApiConfig
          if modelsToUse.length == 0
            manageStatusMessage("No suitable AI models found for #{apiTypeToUse}. Check options or background logs.", 'warn', 5000)
            return
          currentDomainsString = domainsToQuery.sort().join(',')
          cachedDomainsString = if cachedDomains then cachedDomains.sort().join(',') else null
          if cachedDomainsString and currentDomainsString == cachedDomainsString and cachedResponse and cachedApiType == apiTypeToUse
            try
              localLastApiResponse = JSON.parse(cachedResponse)
              descriptionText = null
              if cachedApiType == 'gemini' then descriptionText = localLastApiResponse?.candidates?[0]?.content?.parts?[0]?.text
              else if cachedApiType == 'groq' then descriptionText = localLastApiResponse?.choices?[0]?.message?.content
              if descriptionText
                descriptions = parseAIResponseJSON(descriptionText)
                localDomainDescriptions = descriptions
                localDomainDescriptions[mainDomain] = { why: 'main domain', brief: 'necessary' }
                updateDomainListWithDescriptions(localDomainDescriptions, domainListEl)
                manageStatusMessage("Loaded from cache.", 'info', 2000)
                return
              else throw new Error("No text in cached response.")
            catch e
              console.error "Popup: Failed to use cached response:", e # Formatted
              manageStatusMessage("Cache error. Fetching new data.", 'warn', 3000)

          promptText = "Tell me, as JSON:\nin a `why` field, in twelve words for each, why my browser requests #{domainsToQuery.map((d) -> "`#{d}`").join(', ')} when accessing `#{mainDomain}`;\nin a `brief` field, one word saying whether this domain is `necessary`, `useful`, `optional`, `tracking`, `ad`, or `dangerous` when accessing `#{mainDomain}`;.\nReturn the result as a JSON object with domains as keys and their descriptions as values.\n\nExample response:\n{\"example.com\": {\"why\": \"tracking user behavior.\", \"brief\": \"tracking\"}}"

          attemptFetch = (index) ->
            if index >= modelsToUse.length
              console.error "Popup: All models for #{apiTypeToUse} failed." # Formatted
              manageStatusMessage("All AI models failed. Check console.", 'error', 5000) # User-friendly
              if fallbackMessageDiv then fallbackMessageDiv.style.display = 'none'
              return
            modelName = modelsToUse[index]
            manageStatusMessage("AI request to #{apiTypeToUse} model: #{modelName.split('/').pop()}…", 'info')
            apiCallPromise = if apiTypeToUse == 'gemini' then callGeminiApi(modelName, apiKeyToUse, promptText)
            else if apiTypeToUse == 'groq' then callGroqApi(modelName, apiKeyToUse, promptText)
            else Promise.reject(new Error("Unknown API type: #{apiTypeToUse}"))
            apiCallPromise
              .then (apiInfo) -> handleApiResponse(apiInfo, apiTypeToUse, domainsToQuery, mainDomain)
              .then (success) -> unless success then attemptFetch(index + 1)
              .catch (err) ->
                errorMessage = "Error with #{modelName.split('/').pop()}: #{err.message.substring(0,100)}"
                if err.message.includes("429") then errorMessage = "Rate limit for #{modelName.split('/').pop()}."
                manageStatusMessage(errorMessage, 'error', 5000)
                attemptFetch(index + 1)
          attemptFetch(0)
        )
        .catch (err) ->
          console.error "Popup: Error in API config/fetch process:", err # Formatted
          manageStatusMessage("API configuration error. Check console.", 'error', 5000) # User-friendly

  processBackgroundResponse = (response, activeTab, isInitialCall = false) ->
    if response and response.domains
      if isInitialCall then console.log "Popup: Initial getTabDomains message successful. Response:", response # Formatted
      domainListEl.innerHTML = ''
      mainDomain = new URL(activeTab.url).hostname
      response.domains.forEach (domain) ->
        li = document.createElement 'li'
        checkbox = document.createElement 'input'; checkbox.type = 'checkbox'; checkbox.checked = true
        li.appendChild checkbox
        domainStrong = document.createElement 'strong'; domainStrong.textContent = domain
        li.appendChild domainStrong
        domainListEl.appendChild li
      fetchAndDisplayDescriptions(response.domains, mainDomain)
    else
      manageStatusMessage("No domains found for this tab.", 'info', 3000)

  handleTabQueryResponse = (tabs, isInitialCall = false) ->
    if chrome.runtime.lastError
      console.error "Popup: Initial tab query failed:", chrome.runtime.lastError.message if isInitialCall # Formatted
      console.error "Popup: Tab query failed:", chrome.runtime.lastError.message unless isInitialCall # Formatted
      manageStatusMessage("Error accessing browser tabs. Check console.", 'error', 5000) # User-friendly
      return

    activeTab = tabs[0]
    if activeTab
      if isInitialCall then console.log "Popup: Initial tab query successful. Active tab ID:", activeTab.id, "Sending getTabDomains message." # Formatted
      chrome.runtime.sendMessage { action: "getTabDomains", tabId: activeTab.id }, (response) ->
        if chrome.runtime.lastError
          console.error "Popup: Initial getTabDomains message failed:", chrome.runtime.lastError.message if isInitialCall # Formatted
          console.error "Popup: getTabDomains message failed:", chrome.runtime.lastError.message unless isInitialCall # Formatted
          manageStatusMessage("Error communicating with background. Check console.", 'error', 5000) # User-friendly
          return
        processBackgroundResponse(response, activeTab, isInitialCall)
    else
      console.warn "Popup: Initial tab query returned no active tab." if isInitialCall # Formatted
      console.warn "Popup: Tab query returned no active tab." unless isInitialCall # Formatted
      manageStatusMessage("Could not identify active tab.", 'error', 5000)

  fetchAndDisplayDomainsInitial = () ->
    console.log "Popup: fetchAndDisplayDomainsInitial called. Attempting to query active tab immediately." # Formatted
    chrome.tabs.query { active: true, currentWindow: true }, (tabs) ->
      handleTabQueryResponse(tabs, true)

  fetchAndDisplayDomainsInitial()

  chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
    if request.action == "updatePopupDomains"
      chrome.tabs.query { active: true, currentWindow: true }, (tabs) ->
        activeTab = tabs[0]
        if activeTab and activeTab.id == request.tabId
          processBackgroundResponse({ domains: request.domains }, activeTab)
        true

  copyDomainsButton.addEventListener 'click', () ->
    if localDomainDescriptions and Object.keys(localDomainDescriptions).length > 0
      domainsToCopy = []
      domainListItems = domainListEl.querySelectorAll 'li'
      for li in domainListItems
        checkbox = li.querySelector 'input[type="checkbox"]'
        domainStrong = li.querySelector 'strong'
        if checkbox and domainStrong and checkbox.checked
          domainsToCopy.push domainStrong.textContent
      if domainsToCopy.length > 0
        navigator.clipboard.writeText(domainsToCopy.join('\n')).then () ->
          manageStatusMessage("Copied!", 'success', 2000)
        .catch (err) ->
          console.error "Popup: Failed to copy:", err # Formatted
          manageStatusMessage("Failed to copy.", 'error', 3000)

  clearButton.addEventListener 'click', () ->
    chrome.tabs.query { active: true, currentWindow: true }, (tabs) ->
      if chrome.runtime.lastError
        manageStatusMessage("Error accessing tabs for clear.", 'error', 3000)
        return console.error "Popup: Error querying for clear:", chrome.runtime.lastError.message # Formatted
      activeTab = tabs[0]
      if activeTab
        domainListEl.innerHTML = ''
        manageStatusMessage("List cleared.", 'info', 2000)
        chrome.runtime.sendMessage { action: "clearTabDomains", tabId: activeTab.id }, (response) ->
          if chrome.runtime.lastError
            manageStatusMessage("Failed to clear stored domains.", 'error', 3000)
            console.error "Popup: Error sending clear msg:", chrome.runtime.lastError.message # Formatted
      else
        manageStatusMessage("No active tab found to clear.", 'error', 3000)
        console.error "Popup: No active tab to clear." # Formatted

  showJsonButton.addEventListener 'click', () ->
    if jsonResponseDiv.style.display == 'none'
      if localLastApiResponse
        jsonResponseDiv.textContent = JSON.stringify(localLastApiResponse, null, 2)
        jsonResponseDiv.style.display = 'block'
        showJsonButton.textContent = 'Hide JSON Response'
      else
        jsonResponseDiv.textContent = 'No JSON response available yet.'
        jsonResponseDiv.style.display = 'block'
    else
      jsonResponseDiv.style.display = 'none'
      showJsonButton.textContent = 'Show JSON Response'

  showConsoleButton.addEventListener 'click', () ->
    targetConsoleDiv = document.getElementById 'console-output'
    if targetConsoleDiv # Check if div exists
      if targetConsoleDiv.style.display == 'none'
        targetConsoleDiv.style.display = 'block'
        targetConsoleDiv.scrollTop = targetConsoleDiv.scrollHeight
        showConsoleButton.textContent = 'Hide Console'
      else
        targetConsoleDiv.style.display = 'none'
        showConsoleButton.textContent = 'Show Console'
