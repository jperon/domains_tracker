# coffeelint: disable=max_line_length
document.addEventListener 'DOMContentLoaded', ->
  apiKeyInput = document.getElementById 'geminiApiKey'
  saveButton = document.getElementById 'saveButton'
  statusDiv = document.getElementById 'status'

  # Load saved API key
  chrome.storage.local.get 'geminiApiKey', (data) ->
    if data.geminiApiKey
      apiKeyInput.value = data.geminiApiKey

  # Save API key on button click
  saveButton.addEventListener 'click', ->
    apiKey = apiKeyInput.value
    chrome.storage.local.set { geminiApiKey: apiKey }, ->
      statusDiv.textContent = 'API Key saved.'
      setTimeout (->
        statusDiv.textContent = ''
      ), 2000
