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
  appendConsoleMessage("LOG: " + message, 'log')
  originalConsoleLog.apply(console, arguments)

console.warn = (message) ->
  appendConsoleMessage("WARN: " + message, 'warn')
  originalConsoleWarn.apply(console, arguments)

console.error = (message) ->
  appendConsoleMessage("ERROR: " + message, 'error')
  originalConsoleError.apply(console, arguments)
# coffeelint: disable=max_line_length
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
      descriptionText += " <em class=\"#{briefClass}\">#{domainInfo.brief}</em>:<br/>"
    if domainInfo.why
      descriptionText += " #{domainInfo.why}"

    if descriptionText.length > 0
      li.innerHTML += descriptionText
      li.appendChild document.createElement 'br'

    # Add click listener to copy domain to clipboard
    addClickListener = (element, domainToCopy) ->
      element.addEventListener 'click', () ->
        console.log "Popup: Domain list item clicked:", domainToCopy
        navigator.clipboard.writeText(domainToCopy).then () ->
          console.log "Popup: Copied domain to clipboard:", domainToCopy
          # Display temporary success message near the clicked item
          statusMessage = document.getElementById 'status-message' # Get message element locally
          if statusMessage
            statusMessage.textContent = "Copied '#{domainToCopy}'!"
            statusMessage.style.display = 'block'
            # Position the message near the clicked item (optional, requires more complex positioning)
            # For simplicity, we'll just show the existing message element
            setTimeout () ->
              statusMessage.style.display = 'none'
            , 2000 # Hide after 2 seconds
        .catch (err) ->
          console.error "Popup: Failed to copy domain to clipboard:", err

    addClickListener(domainStrong, domain) # Call the function with the domainStrong element and domain

    domainList.appendChild li
    console.log "Popup: Displaying sorted domain:", domain

# Utility function to fetch and display descriptions for external domains
fetchAndDisplayDescriptions = (domains, mainDomain, domainList) ->
  # Skip fetching description for the main domain
  domainsToQuery = domains.filter (domain) -> domain != mainDomain

  if domainsToQuery.length == 0
    console.log "Popup: No external domains to query for description."
    return

  console.log "Popup: Domains to query:", domainsToQuery

  chrome.storage.local.get ['geminiApiKey', 'availableModels', 'cachedDomains', 'cachedResponse'], (data) ->
    apiKey = data.geminiApiKey
    availableModels = data.availableModels
    cachedDomains = data.cachedDomains
    cachedResponse = data.cachedResponse

    console.log "Popup: Storage data received:", data
    console.log "Popup: API Key:", apiKey ? "Not set"
    console.log "Popup: Available Models:", availableModels ? "Not found"

    # --- Caching Logic Start ---
    currentDomainsString = domainsToQuery.sort().join(',')
    cachedDomainsString = if cachedDomains then cachedDomains.sort().join(',') else null

    if cachedDomainsString and currentDomainsString == cachedDomainsString and cachedResponse
      console.log "Popup: Using cached response for domains:", domainsToQuery
      try
        # Use cached response for display and JSON button
        window.lastGeminiResponse = JSON.parse(cachedResponse)
        descriptionText = window.lastGeminiResponse?.candidates?[0]?.content?.parts?[0]?.text
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
            return # Exit the function after using cache
          else
            throw new Error("Could not find valid JSON object in cached response.")
        else
          throw new Error("Cached response does not contain description text.")
      catch e
        console.error "Popup: Failed to use cached response:", e
        # Fall through to fetch if cache is invalid or invalid
    else
      console.log "Popup: No cache or domains changed. Fetching new descriptions."
    # --- Caching Logic End ---

    if not apiKey
      console.warn "Popup: Gemini API key not set. Please configure it in the options page."
      return

    if not availableModels or availableModels.length == 0
      console.warn "Popup: No available models found. Please check the background script."
      return

    console.log "Popup: API Key and models available. Attempting to fetch descriptions for domains:", domainsToQuery

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
    attemptFetch = (index) ->
      # Get status message element locally
      statusMessage = document.getElementById 'status-message'

      if index >= availableModels.length
        console.error "Popup: All available models failed to fetch descriptions for domains."
        # Display a message indicating failure for all domains
        domainsToQuery.forEach (domain) ->
          li = document.querySelector("li strong:contains('#{domain}')")?.parentNode
          if li
            description = document.createElement 'span'
            description.textContent = " - Could not fetch description."
            li.appendChild document.createElement 'br'
            li.appendChild description
        return

      model = availableModels[index]
      modelName = model.name # Use the full model name

      # Display AI request status message
      # Display AI request status message
      if statusMessage
        statusMessage.textContent = "Sent AI request…"
        statusMessage.style.display = 'block'

      callGeminiApi(modelName, apiKey, promptText)
        .then (info) ->
          console.log "Popup: Received info with model #{modelName}:", info
          # Store the raw JSON response for debugging
          window.lastGeminiResponse = info
          # Assuming the response structure has a 'candidates' array with 'content'
          descriptionText = info?.candidates?[0]?.content?.parts?[0]?.text
          if descriptionText
            console.log "Popup: Successfully fetched descriptions using model #{modelName}"
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
                # --- Caching Logic Store ---
                # Store the raw info object for the JSON button
                chrome.storage.local.set { cachedDomains: domainsToQuery, cachedResponse: JSON.stringify(info) }, () ->
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
                return true # Indicate success
              else
                throw new Error("Could not find valid JSON object in response.")

        .then (success) ->
          # If successful, stop the loop
          unless success
            # Try the next model if not successful
            attemptFetch(index + 1)
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
          attemptFetch(index + 1)
    # Start the fetch attempt with the first model
    attemptFetch(0)

# Utility function to process the response from the background script
processBackgroundResponse = (response, domainList, activeTab) ->
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
    fetchAndDisplayDescriptions(response.domains, mainDomain, domainList)
  else
    console.warn "Popup: No domains found for the active tab."

# Utility function to handle the tab query response
handleTabQueryResponse = (tabs, domainList) ->
  if chrome.runtime.lastError
    console.error "Popup: Error querying tabs:", chrome.runtime.lastError.message
    return

  activeTab = tabs[0]
  if activeTab
    console.log "Popup: Active tab ID:", activeTab.id
    chrome.runtime.sendMessage { action: "getTabDomains", tabId: activeTab.id }, (response) ->
      if chrome.runtime.lastError
        console.error "Popup: Error sending message to background:", chrome.runtime.lastError.message
        return

      processBackgroundResponse(response, domainList, activeTab)
  else
    console.error "Popup: Could not get active tab."

# Function to fetch and display domains for the active tab
fetchAndDisplayDomains = (domainList) ->
  # Get the active tab and request its domains from the background script
  chrome.tabs.query { active: true, currentWindow: true }, (tabs) ->
    handleTabQueryResponse(tabs, domainList)

document.addEventListener 'DOMContentLoaded', () ->
  domainList = document.getElementById 'domain-list'
  clearButton = document.getElementById 'clear-button'
  showJsonButton = document.getElementById 'show-json-button'
  jsonResponseDiv = document.getElementById 'json-response'
  showConsoleButton = document.getElementById 'show-console-button'
  consoleOutputDiv = document.getElementById 'console-output'
  statusMessage = document.getElementById 'status-message' # Get message element

  # Fetch and display domains when the popup is opened
  fetchAndDisplayDomains(domainList)

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
          statusMessage = document.getElementById 'status-message' # Get message element locally
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
            return

          console.log "Popup: Received response from background for clear action:", response
      else
        console.error "Popup: Could not get active tab to clear domains."

  # Add event listener for the Show JSON button
  showJsonButton.addEventListener 'click', () ->
    console.log "Popup: Show JSON button clicked."
    if jsonResponseDiv.style.display == 'none'
      if window.lastGeminiResponse
        jsonResponseDiv.textContent = JSON.stringify(window.lastGeminiResponse, null, 2)
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
      showConsoleButton.textContent = 'Hide Console'
    else
      consoleOutputDiv.style.display = 'none'
      showConsoleButton.textContent = 'Show Console'
