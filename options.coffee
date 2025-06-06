# coffeelint: disable=max_line_length
document.addEventListener 'DOMContentLoaded', ->
  geminiApiKeyInput = document.getElementById 'geminiApiKey'
  groqApiKeyInput = document.getElementById 'groqApiKey'
  saveButton = document.getElementById 'saveButton'
  statusDiv = document.getElementById 'status'

  # Load saved API keys
  chrome.storage.local.get ['geminiApiKey', 'groqApiKey'], (data) ->
    if data.geminiApiKey
      geminiApiKeyInput.value = data.geminiApiKey
    if data.groqApiKey
      groqApiKeyInput.value = data.groqApiKey

  # Save API keys on button click
  saveButton.addEventListener 'click', ->
    geminiApiKey = geminiApiKeyInput.value
    groqApiKey = groqApiKeyInput.value
    chrome.storage.local.set { geminiApiKey: geminiApiKey, groqApiKey: groqApiKey }, ->
      statusDiv.textContent = 'Options: API Keys saved.'
      setTimeout (->
        statusDiv.textContent = ''
      ), 2000
