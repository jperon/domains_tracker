# Redirect console messages to a div
originalConsoleLog = console.log
originalConsoleWarn = console.warn
originalConsoleError = console.error

appendConsoleMessage = (message, level = 'log') ->
  consoleOutputDiv = document.getElementById 'console-output'
  if consoleOutputDiv
    messageElement = document.createElement 'div'
    messageElement.textContent = message
    messageElement.classList.add "console-#{level}"
    consoleOutputDiv.appendChild messageElement
    # Auto-scroll to the bottom
    consoleOutputDiv.scrollTop = consoleOutputDiv.scrollHeight

console.log = (message) ->
  appendConsoleMessage("Popup: LOG: " + message, 'log')
  originalConsoleLog.apply(console, arguments)

console.warn = (message) ->
  appendConsoleMessage("Popup: WARN: " + message, 'warn')
  originalConsoleWarn.apply(console, arguments)

console.error = (message) ->
  appendConsoleMessage("Popup: ERROR: " + message, 'error')
  originalConsoleError.apply(console, arguments)
# coffeelint: disable=max_line_length
# Constants for Groq API
GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions"

console.log "Popup: DOMContentLoaded event fired. Initializing popup script."

# Utility function to call the Gemini API
callGeminiApi = (modelName, apiKey, promptText) ->
  console.log "Popup: Attempting fetch with model #{modelName}"
  fetch("https://generativelanguage.googleapis.com/v1/models/#{modelName.split('/').pop()}:generateContent?key=#{apiKey}",
    method: 'POST'
    headers:
      'Content-Type': 'application/json'
    body: JSON.stringify(
      contents: [
        parts: [
          text: promptText
        ]
      ]
      generationConfig:
        maxOutputTokens: 20000
        temperature: 0.0
    )
  )
  .then (response) ->
    console.log "Popup: Received fetch response with model #{modelName}:", response
    if response.ok
      response.json()
    else
      # If response is not ok, throw an error to move to the next model
      response.text().then (text) ->
        throw new Error("HTTP error! status: #{response.status}, body: #{text}")

# Utility function to update the domain list with descriptions
updateDomainListWithDescriptions = (descriptions, domainList) ->
  console.log "Popup: Parsed descriptions:", descriptions

  # Define the desired sorting order
  briefOrder = ['necessary', 'useful', 'optional', 'ad', 'tracking', 'dangerous']

  # Convert descriptions object to an array for sorting
  domainArray = []
  for domain, domainInfo of descriptions
    domainArray.push { domain: domain, domainInfo: domainInfo }

  # Sort the array based on the brief order
  domainArray.sort (a, b) ->
    briefA = a.domainInfo.brief ? '' # Handle cases with no brief
    briefB = b.domainInfo.brief ? ''
    indexA = briefOrder.indexOf(briefA)
    indexB = briefOrder.indexOf(briefB)

    # Handle cases where brief is not in the defined order (put them at the end)
    if indexA == -1 and indexB == -1
      0 # Maintain original order relative to each other
    else if indexA == -1
      1 # b comes first
    else if indexB == -1
      -1 # a comes first
    else
      indexA - indexB # Sort based on the defined order

  # Clear existing list items
  domainList.innerHTML = ''

  # Create and append list items in the sorted order
  for domainObj in domainArray
    domain = domainObj.domain
    domainInfo = domainObj.domainInfo
    console.log "Popup: Processing domain:", domain, "Brief:", domainInfo.brief

    li = document.createElement 'li'
    # Create a checkbox for the domain
    checkbox = document.createElement 'input'
    checkbox.type = 'checkbox'
    console.log "Popup: Checking checkbox for domain #{domain} with brief: #{domainInfo.brief}" # Added log
    # Ensure checkboxes for necessary and useful domains are checked, setting checked property as a string
    if domainInfo.brief in ['necessary', 'useful'] then checkbox.setAttribute('checked', 'checked')
    li.appendChild checkbox

    # Create a strong element for the domain name
    domainStrong = document.createElement 'strong'
    domainStrong.textContent = domain
    li.appendChild domainStrong

    descriptionText = ""
    if domainInfo.brief
      briefClass = ''
      if domainInfo.brief in ['necessary', 'useful']
        briefClass = 'brief-green'
      else if domainInfo.brief in ['ad', 'tracking', 'dangerous']
        briefClass = 'brief-red'
      descriptionText = " - <span class=\"#{briefClass}\">#{domainInfo.brief}</span>:<br/> #{domainInfo.why}"
    else if domainInfo.why
      descriptionText = " - #{domainInfo.why}"

    # Create a span for the description
    descriptionSpan = document.createElement 'span'
    descriptionSpan.innerHTML = descriptionText # Use innerHTML to render HTML tags in descriptionText
    li.appendChild descriptionSpan

    domainList.appendChild li
    console.log "Popup: Displaying sorted domain:", domain

# Utility function to call the Groq API
callGroqApi = (modelName, apiKey, promptText) ->
  console.log "Popup: Attempting fetch with Groq model #{modelName}"
  fetch(GROQ_API_URL,
    method: 'POST'
    headers:
      'Content-Type': 'application/json'
      'Authorization': "Bearer #{apiKey}"
    body: JSON.stringify(
      messages: [
        { role: "user", content: promptText }
      ]
      model: modelName
      temperature: 0
      max_completion_tokens: 1024
      top_p: 1
      stream: false
      stop: null
    )
  )
  .then (response) ->
    console.log "Popup: Received fetch response with Groq model #{modelName}:", response
    if response.ok
      response.json()
    else
      response.text().then (text) ->
        throw new Error("HTTP error! status: #{response.status}, body: #{text}")

  .catch (err) -> # Add this catch block
    console.error "Popup: Fetch error in callGroqApi for model #{modelName}:", err
    throw err # Re-throw the error so it can be caught by attemptFetch

# Utility function to determine API configuration (key, type, models)
determineApiConfig = (availableModels) ->
  console.log "Popup: Determining API configuration."
  # Return a Promise that resolves with the API configuration
  new Promise (resolve, reject) ->
    chrome.storage.local.get ['geminiApiKey', 'groqApiKey'], (data) ->
      if chrome.runtime.lastError
        reject(chrome.runtime.lastError)
        return

      geminiApiKey = data.geminiApiKey
      groqApiKey = data.groqApiKey
      apiTypeToUse = null
      apiKeyToUse = null
      fallbackKeyUsed = false
      modelsToUse = []

      console.log "Popup: Gemini API Key:", geminiApiKey ? "Not set"
      console.log "Popup: Groq API Key:", groqApiKey ? "Not set"
      console.log "Popup: Available Models:", availableModels ? "Not found"

      if geminiApiKey
        apiTypeToUse = 'gemini'
        apiKeyToUse = geminiApiKey
        console.log "Popup: Using Gemini API."
        if availableModels and availableModels.length > 0
          # Filter for Gemini models (assuming they have a 'name' property and include 'gemini') and map to name
          modelsToUse = availableModels.filter (model) -> model? and typeof model == 'object' and model.name? and model.name.includes('gemini')
          modelsToUse = modelsToUse.map (model) -> model.name
        else
          console.warn "Popup: No Gemini models found. Please check the background script."
      else if groqApiKey
        apiTypeToUse = 'groq'
        apiKeyToUse = groqApiKey
        console.log "Popup: Using Groq API."
        if availableModels and availableModels.length > 0
          # Filter for Groq models (assuming they have 'object: "model"' and an 'id') and map to id
          modelsToUse = availableModels.filter (model) -> model? and typeof model == 'object' and model.object == 'model' and model.id?
          modelsToUse = modelsToUse.map (model) -> model.id
        else
          console.warn "Popup: No availableModels found for Groq."
          modelsToUse = [] # No fallback model

      # If no API key is set, display a message and return
      if not apiKeyToUse
        console.warn "Popup: No API key set. Please add one on the options page."
        fallbackMessageDiv = document.getElementById 'fallback-key-message'
        if fallbackMessageDiv
          fallbackMessageDiv.innerHTML = "<strong><span style=\"color: orange;\">Please add your API key on the <a href=\"options.html\" target=\"_blank\">options page</a>.</span></strong>"
          fallbackMessageDiv.style.display = 'block'
        # Resolve with empty config, the calling function handles this
        resolve { apiTypeToUse: null, apiKeyToUse: null, modelsToUse: [], fallbackKeyUsed: false }
      else
        if modelsToUse.length == 0 and apiTypeToUse != null # Only warn if an API type was determined but no models found
          console.warn "Popup: No suitable models found for API type #{apiTypeToUse}."
        # Filter out any null or undefined models
        modelsToUse = modelsToUse.filter (model) -> model?

        resolve { apiTypeToUse, apiKeyToUse, modelsToUse, fallbackKeyUsed: false } # Set fallbackKeyUsed to false

# Utility function to handle API response parsing and UI update
handleApiResponse = (info, apiType, domainsToQuery, mainDomain, domainList, statusMessage) ->
  console.log "Popup: Handling API response for API type:", apiType
  window.lastApiResponse = info # Store the raw JSON response for debugging
  descriptionText = null

  if apiType == 'gemini'
    descriptionText = info?.candidates?[0]?.content?.parts?[0]?.text
  else if apiType == 'groq'
    descriptionText = info?.choices?[0]?.message?.content

  if descriptionText
    console.log "Popup: Successfully fetched descriptions using API type #{apiType}"
    try
      # Find the first opening brace and the last closing brace
      startIndex = descriptionText.indexOf('{')
      endIndex = descriptionText.lastIndexOf('}')

      if startIndex != -1 and endIndex != -1 and endIndex > startIndex
        # Extract the JSON string
        jsonString = descriptionText.substring(startIndex, endIndex + 1)
        descriptions = JSON.parse(jsonString)
        window.domainDescriptions = descriptions # Store descriptions

        # --- Caching Logic Store ---
        # Store the raw info object and API type for the JSON button and cache
        chrome.storage.local.set { cachedDomains: domainsToQuery, cachedResponse: JSON.stringify(info), cachedApiType: apiType }, () ->
          if chrome.runtime.lastError
            console.error "Popup: Error saving cache:", chrome.runtime.lastError.message
          else
            console.log "Popup: Cache saved successfully."
        # --- Caching Logic Store End ---

        # Add the main domain with hardcoded description at the beginning
        descriptions[mainDomain] = { why: 'main domain', brief: 'necessary' }
        updateDomainListWithDescriptions(descriptions, domainList)
        # Hide AI request status message on success
        if statusMessage
          statusMessage.style.display = 'none'
        # Hide fallback message on success
        return true # Indicate success
      else
        throw new Error("Could not find valid JSON object in response.")
    catch e
      console.error "Popup: Failed to parse API response:", e
      throw e # Re-throw to be caught by the attemptFetch catch block
  else
    throw new Error("API response does not contain description text.")


# Utility function to fetch and display descriptions for external domains
fetchAndDisplayDescriptions = (domains, mainDomain, domainList, statusMessage) ->
  chrome.storage.local.get ['availableModels', 'cachedDomains', 'cachedResponse', 'cachedApiType'], (data) ->
    availableModels = data.availableModels
    cachedDomains = data.cachedDomains
    cachedResponse = data.cachedResponse
    cachedApiType = data.cachedApiType

    console.log "Popup: Storage data received:", data
    console.log "Popup: Available Models:", availableModels ? "Not found"

    # Skip fetching description for the main domain
    domainsToQuery = domains.filter (domain) -> domain != mainDomain

    if domainsToQuery.length == 0
      console.log "Popup: No external domains to query for description."
      # Hide fallback message if no domains to query
      fallbackMessageDiv = document.getElementById 'fallback-key-message'
      if fallbackMessageDiv
        fallbackMessageDiv.style.display = 'none'
      # Hide AI request status message if no domains to query
      if statusMessage
        statusMessage.style.display = 'none'
      return

    console.log "Popup: Domains to query:", domainsToQuery

    # Determine API configuration asynchronously
    determineApiConfig(availableModels)
      .then ({ apiTypeToUse, apiKeyToUse, modelsToUse, fallbackKeyUsed }) ->
        if not apiKeyToUse
          console.warn "Popup: No API key available after determining config."
          # Hide AI request status message if no API key
          if statusMessage
            statusMessage.style.display = 'none'
          return

        if modelsToUse.length == 0
          console.warn "Popup: No suitable models found for API type #{apiTypeToUse} after determining config."
          # Hide AI request status message if no models
          if statusMessage
            statusMessage.style.display = 'none'
          return

        # --- Caching Logic Start ---
        currentDomainsString = domainsToQuery.sort().join(',')
        cachedDomainsString = if cachedDomains then cachedDomains.sort().join(',') else null

        # Check if cached data matches current domains and API type
        if cachedDomainsString and currentDomainsString == cachedDomainsString and cachedResponse and cachedApiType == apiTypeToUse
          console.log "Popup: Using cached response for domains:", domainsToQuery, "and API type:", cachedApiType
          try
            # Use cached response for display and JSON button
            window.lastApiResponse = JSON.parse(cachedResponse) # Use a generic name
            descriptionText = null
            if cachedApiType == 'gemini'
              descriptionText = window.lastApiResponse?.candidates?[0]?.content?.parts?[0]?.text
            else if cachedApiType == 'groq'
              descriptionText = window.lastApiResponse?.choices?[0]?.message?.content

            if descriptionText
              # Find the first opening brace and the last closing brace
              startIndex = descriptionText.indexOf('{')
              endIndex = descriptionText.lastIndexOf('}')

              if startIndex != -1 and endIndex != -1 and endIndex > startIndex
                # Extract the JSON string
                jsonString = descriptionText.substring(startIndex, endIndex + 1)
                descriptions = JSON.parse(jsonString)
                window.domainDescriptions = descriptions # Store descriptions
                # Add the main domain with hardcoded description at the beginning
                descriptions[mainDomain] = { why: 'main domain', brief: 'necessary' }
                updateDomainListWithDescriptions(descriptions, domainList)
                # Hide fallback message if cache is used successfully
                # Hide AI request status message if cache is used successfully
                if statusMessage
                  statusMessage.style.display = 'none'
                return # Exit the function after using cache
              else
                throw new Error("Could not find valid JSON object in cached response.")
            else
              throw new Error("Cached response does not contain description text.")
          catch e
            console.error "Popup: Failed to use cached response:", e
            # Fall through to fetch if cache is invalid or invalid
        else
          console.log "Popup: No cache, domains changed, or API type changed. Fetching new descriptions."
        # --- Caching Logic End ---


        console.log "Popup: API Key and models available. Attempting to fetch descriptions for domains using #{apiTypeToUse}:", domainsToQuery

        # Construct the combined prompt
        domainListString = domainsToQuery.map (d) -> "`#{d}`"
        promptText = "Tell me, as JSON:
          in a `why` field, in twelve words for each, why my browser requests #{domainListString.join(', ')} when accessing `#{mainDomain}`;
          in a `brief` field, one word saying whether this domain is `necessary`, `useful`, `optional`, `tracking`, `ad`, or `dangerous` when accessing `#{mainDomain}`;.
          Return the result as a JSON object with domains as keys and their descriptions as values.
          \nExample response:\n{\"example.com\": {\"why\": \"tracking user behavior.\", \"brief\": \"tracking\"}}
        "
        console.log "Popup: Constructed prompt:", promptText

        # Function to attempt fetching descriptions with a specific model
        attemptFetch = (index, statusMessage) ->
          # Get status message element locally

          if modelsToUse.length == 0
            console.warn "Popup: No suitable models available for API type #{apiTypeToUse}."
            # Hide AI request status message
            if statusMessage
              statusMessage.style.display = 'none'
            return # Stop the fetch attempt process

          if index >= modelsToUse.length
            console.error "Popup: All available models for #{apiTypeToUse} failed to fetch descriptions for domains."
            # Display a message indicating failure for all domains
            domainsToQuery.forEach (domain) ->
              li = document.querySelector("li strong:contains('#{domain}')")?.parentNode
              if li
                description = document.createElement 'span'
                description.textContent = " - Could not fetch description."
                li.appendChild document.createElement 'br'
                li.appendChild description
            # Hide fallback message on failure
            fallbackMessageDiv = document.getElementById 'fallback-key-message'
            if fallbackMessageDiv
              fallbackMessageDiv.style.display = 'none'
            # Hide AI request status message on failure
            if statusMessage
              statusMessage.style.display = 'none'
            return

          model = modelsToUse[index]
          modelName = model # Use the full model name (which is now a string)

          # Display AI request status message
          if statusMessage
            statusMessage.textContent = "Sent AI request to #{apiTypeToUse} with model #{modelName}…"
            statusMessage.style.display = 'block'

          apiCallPromise = if apiTypeToUse == 'gemini'
            callGeminiApi(modelName, apiKeyToUse, promptText)
          else if apiTypeToUse == 'groq'
            callGroqApi(modelName, apiKeyToUse, promptText)
          else
            Promise.reject(new Error("Unknown API type: #{apiTypeToUse}")) # Handle unexpected API type

          apiCallPromise
            .then (info) ->
              handleApiResponse(info, apiTypeToUse, domainsToQuery, mainDomain, domainList, statusMessage)
            .then (success) ->
              # If successful, stop the loop
              unless success
                # Try the next model if not successful
                attemptFetch(index + 1, statusMessage)
            .catch (err) ->
              # Log a more concise message for failed attempts
              errorMessage = "Could not fetch description."
              if err.message.includes("HTTP error! status: 429")
                console.warn "Popup: Model #{modelName} failed due to rate limiting (429)."
                errorMessage = "Rate limit exceeded for #{modelName}."
              else
                console.warn "Popup: Model #{modelName} failed:", err.message
                errorMessage = "Error with #{modelName}: #{err.message}"

              # Display temporary error message
              if statusMessage
                statusMessage.textContent = errorMessage
                statusMessage.style.display = 'block'
                setTimeout () ->
                  statusMessage.style.display = 'none'
                , 5000 # Show error for 5 seconds

              # Try the next model
              attemptFetch(index + 1, statusMessage)
        # Start the fetch attempt with the first model
        attemptFetch(0, statusMessage)
      .catch (err) ->
        console.error "Popup: Error determining API config:", err

# Utility function to process the response from the background script
processBackgroundResponse = (response, domainList, activeTab, statusMessage) ->
  console.log "Popup: Received response from background:", response
  if response and response.domains
    # Clear existing list items
    domainList.innerHTML = ''

    # Display domains for the active tab
    # Get the main domain of the active tab
    mainDomain = new URL(activeTab.url).hostname

    response.domains.forEach (domain) ->
      li = document.createElement 'li'

      # Create a checkbox for the domain
      checkbox = document.createElement 'input'
      checkbox.type = 'checkbox'
      checkbox.setAttribute('checked', 'checked') # Set to checked by default
      li.appendChild checkbox

      # Create a strong element for the domain name
      domainStrong = document.createElement 'strong'
      domainStrong.textContent = domain
      li.appendChild domainStrong

      domainList.appendChild li
      console.log "Popup: Displaying domain with checkbox:", domain

    # Fetch and display descriptions for external domains
    fetchAndDisplayDescriptions(response.domains, mainDomain, domainList, statusMessage)
  else
    console.warn "Popup: No domains found for the active tab."
    # Hide AI request status message if no domains
    if statusMessage
      statusMessage.style.display = 'none'


# Utility function to handle the tab query response
handleTabQueryResponse = (tabs, domainList, statusMessage) ->
  if chrome.runtime.lastError
    console.error "Popup: Error querying tabs:", chrome.runtime.lastError.message
    # Hide AI request status message on error
    if statusMessage
      statusMessage.style.display = 'none'
    return

  activeTab = tabs[0]
  if activeTab
    console.log "Popup: Active tab ID when requesting domains:", activeTab.id # Added log
    chrome.runtime.sendMessage { action: "getTabDomains", tabId: activeTab.id }, (response) ->
      if chrome.runtime.lastError
        console.error "Popup: Error sending message to background:", chrome.runtime.lastError.message
        # Hide AI request status message on error
        if statusMessage
          statusMessage.style.display = 'none'
        return

      processBackgroundResponse(response, domainList, activeTab, statusMessage)
  else
    console.error "Popup: Could not get active tab."
    # Hide AI request status message if no active tab
    if statusMessage
      statusMessage.style.display = 'none'


# Function to fetch and display domains for the active tab
fetchAndDisplayDomains = (domainList, statusMessage) ->
  # Get the active tab and request its domains from the background script
  setTimeout () ->
    chrome.tabs.query { active: true, currentWindow: true }, (tabs) ->
      handleTabQueryResponse(tabs, domainList, statusMessage)
  , 500 # Add a 500ms delay

document.addEventListener 'DOMContentLoaded', () ->
  domainList = document.getElementById 'domain-list'
  clearButton = document.getElementById 'clear-button'
  showJsonButton = document.getElementById 'show-json-button'
  jsonResponseDiv = document.getElementById 'json-response'
  showConsoleButton = document.getElementById 'show-console-button'
  consoleOutputDiv = document.getElementById 'console-output'
  statusMessage = document.getElementById 'status-message' # Get message element

  # Fetch and display domains when the popup is opened
  fetchAndDisplayDomains(domainList, statusMessage)

  # Add listener for domain updates from the background script
  chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
    if request.action == "updatePopupDomains"
      console.log "Popup: Received domain update from background for tab #{request.tabId}:", request.domains
      # Get the currently active tab
      chrome.tabs.query { active: true, currentWindow: true }, (tabs) ->
        activeTab = tabs[0]
        if activeTab and activeTab.id == request.tabId # Check if the update is for the active tab
          console.log "Popup: Processing domain update for active tab #{activeTab.id}."
          processBackgroundResponse({ domains: request.domains }, domainList, activeTab, statusMessage)
        else if activeTab
          console.log "Popup: Received domain update for inactive tab #{request.tabId}. Current active tab is #{activeTab.id}. Ignoring."
        else
          console.error "Popup: Could not get active tab to process domain update."
        # Return true to indicate that sendResponse will be called asynchronously
        true

  # Add event listener for the Copy button
  copyDomainsButton = document.getElementById 'copy-domains-button'
  copyDomainsButton.addEventListener 'click', () ->
    console.log "Popup: Copy button clicked."
    if window.domainDescriptions
      domainsToCopy = []
      # Iterate through list items and check if the checkbox is selected
      domainListItems = domainList.querySelectorAll 'li'
      for li in domainListItems
        checkbox = li.querySelector 'input[type="checkbox"]'
        domainStrong = li.querySelector 'strong'
        if checkbox and domainStrong and checkbox.checked
          domainsToCopy.push domainStrong.textContent

      if domainsToCopy.length > 0
        domainsString = domainsToCopy.join('\n')
        navigator.clipboard.writeText(domainsString).then () ->
          console.log "Popup: Copied domains to clipboard:", domainsToCopy
          # Display temporary success message
          # Use statusMessage from outer scope
          if statusMessage
            statusMessage.textContent = "Copied!"
            statusMessage.style.display = 'block'
            setTimeout () ->
              statusMessage.style.display = 'none'
            , 2000 # Hide after 2 seconds
        .catch (err) ->
          console.error "Popup: Failed to copy domains to clipboard:", err
          # Optional: Display a temporary error message
      else
        console.log "Popup: No useful or necessary domains found to copy."
        # Optional: Display a temporary message
    else
      console.log "Popup: Domain descriptions not available yet."
      # Optional: Display a temporary message

  # Add event listener for the Clear button
  clearButton.addEventListener 'click', () ->
    console.log "Popup: Clear button clicked."
    # Get the active tab ID to clear its domains
    chrome.tabs.query { active: true, currentWindow: true }, (tabs) ->
      if chrome.runtime.lastError
        console.error "Popup: Error querying tabs for clear action:", chrome.runtime.lastError.message
        # Hide AI request status message on error
        if statusMessage
          statusMessage.style.display = 'none'
        return

      activeTab = tabs[0]
      if activeTab
        console.log "Popup: Clearing domains for tab ID:", activeTab.id
        # Clear the displayed list
        domainList.innerHTML = ''
        # Send message to background script to clear stored domains
        chrome.runtime.sendMessage { action: "clearTabDomains", tabId: activeTab.id }, (response) ->
          if chrome.runtime.lastError
            console.error "Popup: Error sending clear message to background:", chrome.runtime.lastError.message
            # Hide AI request status message on error
            if statusMessage
              statusMessage.style.display = 'none'
            return

          console.log "Popup: Received response from background for clear action:", response
          # Hide AI request status message on clear
          if statusMessage
            statusMessage.style.display = 'none'
      else
        console.error "Popup: Could not get active tab to clear domains."
        # Hide AI request status message if no active tab
        if statusMessage
          statusMessage.style.display = 'none'

  # Add event listener for the Show JSON button
  showJsonButton.addEventListener 'click', () ->
    console.log "Popup: Show JSON button clicked."
    if jsonResponseDiv.style.display == 'none'
      if window.lastApiResponse
        jsonResponseDiv.textContent = JSON.stringify(window.lastApiResponse, null, 2)
        jsonResponseDiv.style.display = 'block'
        showJsonButton.textContent = 'Hide JSON Response'
      else
        jsonResponseDiv.textContent = 'No JSON response available yet.'
        jsonResponseDiv.style.display = 'block'
        showJsonButton.textContent = 'Hide JSON Response'
    else
      jsonResponseDiv.style.display = 'none'
      showJsonButton.textContent = 'Show JSON Response'

  # Add event listener for the Show Console button
  showConsoleButton.addEventListener 'click', () ->
    console.log "Popup: Show Console button clicked."
    if consoleOutputDiv.style.display == 'none'
      consoleOutputDiv.style.display = 'block'
      consoleOutputDiv.scrollTop = consoleOutputDiv.scrollHeight # Scroll to bottom when shown
      showConsoleButton.textContent = 'Hide Console'
    else
      consoleOutputDiv.style.display = 'none'
      showConsoleButton.textContent = 'Show Console'
