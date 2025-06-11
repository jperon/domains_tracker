# coffeelint: disable=max_line_length
document.addEventListener 'DOMContentLoaded', ->
  geminiApiKeyInput = document.getElementById 'geminiApiKey'
  groqApiKeyInput = document.getElementById 'groqApiKey'
  maxLogEntriesInput = document.getElementById 'maxLogEntries' # New
  saveButton = document.getElementById 'saveButton'
  statusDiv = document.getElementById 'status'

  DEFAULT_MAX_LOG_ENTRIES = 200 # Default value for log entries

  # Load saved settings
  chrome.storage.local.get ['geminiApiKey', 'groqApiKey', 'maxLogEntriesConfig'], (data) ->
    if chrome.runtime.lastError
      statusDiv.textContent = 'Options: Error loading settings.'
      console.error "Error loading settings:", chrome.runtime.lastError.message
      return

    if data.geminiApiKey
      geminiApiKeyInput.value = data.geminiApiKey
    if data.groqApiKey
      groqApiKeyInput.value = data.groqApiKey

    if data.maxLogEntriesConfig isnt undefined
      maxLogEntriesInput.value = data.maxLogEntriesConfig
    else
      maxLogEntriesInput.value = DEFAULT_MAX_LOG_ENTRIES

  # Save settings on button click
  saveButton.addEventListener 'click', ->
    geminiApiKey = geminiApiKeyInput.value
    groqApiKey = groqApiKeyInput.value

    # Validate and get maxLogEntriesValue
    rawMaxLogEntries = maxLogEntriesInput.value
    maxLogEntriesValue = parseInt(rawMaxLogEntries, 10)

    if isNaN(maxLogEntriesValue) or maxLogEntriesValue < 50 or maxLogEntriesValue > 1000
      statusDiv.textContent = 'Options: Invalid Max Log Entries value (must be 50-1000). Using default 200.'
      statusDiv.style.color = 'red'
      maxLogEntriesValue = DEFAULT_MAX_LOG_ENTRIES # Fallback to default
      maxLogEntriesInput.value = maxLogEntriesValue # Update input to reflect actual saved value
    else
      statusDiv.textContent = '' # Clear previous error if any
      statusDiv.style.color = 'green'


    settingsToSave =
      geminiApiKey: geminiApiKey
      groqApiKey: groqApiKey
      maxLogEntriesConfig: maxLogEntriesValue

    chrome.storage.local.set settingsToSave, ->
      if chrome.runtime.lastError
        statusDiv.textContent = 'Options: Error saving settings.'
        statusDiv.style.color = 'red'
        console.error "Error saving settings:", chrome.runtime.lastError.message
      else
        statusDiv.textContent = 'Options: Settings saved.'
        statusDiv.style.color = 'green' # Default color for success

      setTimeout (->
        statusDiv.textContent = ''
      ), 3000 # Clear status message after 3 seconds
