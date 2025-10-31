local config = require('i18n.config')
local utils = require('i18n.utils')
local BaseTranslator = require('i18n.translator.base').BaseTranslator
local curl = require('plenary.curl')

local M = {}

---@class DeepLTranslator : BaseTranslator
local DeepLTranslator = setmetatable({}, { __index = BaseTranslator })
DeepLTranslator.__index = DeepLTranslator

--- Create a new DeepL Translator instance
---@return DeepLTranslator
function DeepLTranslator:new()
  local obj = BaseTranslator:new('deepl')
  setmetatable(obj, self)
  return obj
end

--- Get service configuration
---@return I18nTranslatorServiceConfig config
function DeepLTranslator:get_config()
  local conf = config.get()
  return conf.translator.services.deepl or {}
end

--- Check if translator is available
---@return boolean available
---@return string|nil error
function DeepLTranslator:is_available()
  local service_config = self:get_config()

  if not service_config.api_key then
    return false, 'DeepL API key not configured'
  end

  return true, nil
end

--- Map language codes to DeepL format
--- DeepL uses uppercase for target languages and some specific codes
---@param lang string Language code
---@param is_target boolean Whether this is a target language
---@return string deepl_lang DeepL language code
local function map_language_code(lang, is_target)
  -- Convert to uppercase for DeepL
  local deepl_lang = lang:upper()

  -- DeepL specific mappings
  local mappings = {
    EN = is_target and 'EN-US' or 'EN', -- English has variants for target
    PT = is_target and 'PT-PT' or 'PT', -- Portuguese has variants
  }

  return mappings[deepl_lang] or deepl_lang
end

--- Translate text using DeepL API
---@param text string Text to translate
---@param from_lang string Source language code
---@param to_lang string Target language code
---@return string|nil translated Translated text or nil on error
---@return string|nil error Error message if translation failed
function DeepLTranslator:translate(text, from_lang, to_lang)
  if not text or text == '' then
    return '', nil
  end

  local service_config = self:get_config()

  if not service_config.api_key then
    return nil, 'API key not configured'
  end

  -- Determine API endpoint (Free vs Pro)
  -- Free API keys end with ':fx'
  local is_free = service_config.api_key:match(':fx$') ~= nil
  local base_url = is_free and 'https://api-free.deepl.com/v2/translate' or 'https://api.deepl.com/v2/translate'

  -- Map language codes to DeepL format
  local source_lang = map_language_code(from_lang, false)
  local target_lang = map_language_code(to_lang, true)

  -- Build request body (URL-encoded form data for DeepL)
  local body = string.format('text=%s&source_lang=%s&target_lang=%s', vim.uri_encode(text), source_lang, target_lang)

  -- Make HTTP POST request
  local response = curl.post(base_url, {
    headers = {
      ['Authorization'] = 'DeepL-Auth-Key ' .. service_config.api_key,
      ['Content-Type'] = 'application/x-www-form-urlencoded',
    },
    body = body,
  })

  if response.status ~= 200 then
    -- Try to parse error message
    local ok, error_data = pcall(vim.fn.json_decode, response.body)

    if ok and error_data and error_data.message then
      return nil, 'DeepL API error: ' .. error_data.message
    end

    return nil, 'HTTP error: ' .. response.status
  end

  -- Parse response
  local ok, data = pcall(vim.fn.json_decode, response.body)

  if not ok or not data then
    return nil, 'Failed to parse response'
  end

  -- Extract translated text
  -- Format: { translations: [{ text: "...", detected_source_language: "..." }] }
  if data.translations and data.translations[1] and data.translations[1].text then
    return data.translations[1].text, nil
  end

  return nil, 'No translation found in response'
end

--- Batch translate multiple texts (DeepL supports this natively)
---@param texts string[] Texts to translate
---@param from_lang string Source language code
---@param to_lang string Target language code
---@return table<number, string> translations Map of index to translated text
---@return table<number, string> errors Map of index to error message
function DeepLTranslator:batch_translate(texts, from_lang, to_lang)
  if #texts == 0 then
    return {}, {}
  end

  local service_config = self:get_config()

  if not service_config.api_key then
    local errors = {}
    for i = 1, #texts do
      errors[i] = 'API key not configured'
    end
    return {}, errors
  end

  -- Determine API endpoint
  local is_free = service_config.api_key:match(':fx$') ~= nil
  local base_url = is_free and 'https://api-free.deepl.com/v2/translate' or 'https://api.deepl.com/v2/translate'

  -- Map language codes
  local source_lang = map_language_code(from_lang, false)
  local target_lang = map_language_code(to_lang, true)

  -- Build request body with multiple text parameters
  local body_parts = {}
  for _, text in ipairs(texts) do
    table.insert(body_parts, 'text=' .. vim.uri_encode(text))
  end
  table.insert(body_parts, 'source_lang=' .. source_lang)
  table.insert(body_parts, 'target_lang=' .. target_lang)

  local body = table.concat(body_parts, '&')

  -- Make HTTP POST request
  local response = curl.post(base_url, {
    headers = {
      ['Authorization'] = 'DeepL-Auth-Key ' .. service_config.api_key,
      ['Content-Type'] = 'application/x-www-form-urlencoded',
    },
    body = body,
  })

  if response.status ~= 200 then
    local errors = {}
    for i = 1, #texts do
      errors[i] = 'HTTP error: ' .. response.status
    end
    return {}, errors
  end

  -- Parse response
  local ok, data = pcall(vim.fn.json_decode, response.body)

  if not ok or not data or not data.translations then
    local errors = {}
    for i = 1, #texts do
      errors[i] = 'Failed to parse response'
    end
    return {}, errors
  end

  -- Extract translations
  local translations = {}
  local errors = {}

  for i, translation_data in ipairs(data.translations) do
    if translation_data.text then
      translations[i] = translation_data.text
    else
      errors[i] = 'No translation found'
    end
  end

  return translations, errors
end

--- Create and return a new instance
---@return DeepLTranslator
function M.new()
  return DeepLTranslator:new()
end

return M
