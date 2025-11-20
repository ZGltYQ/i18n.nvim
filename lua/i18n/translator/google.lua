local config = require('i18n.config')
local utils = require('i18n.utils')
local BaseTranslator = require('i18n.translator.base').BaseTranslator
local curl = require('plenary.curl')

local M = {}

---@class GoogleTranslator : BaseTranslator
local GoogleTranslator = setmetatable({}, { __index = BaseTranslator })
GoogleTranslator.__index = GoogleTranslator

--- Create a new Google Translator instance
---@return GoogleTranslator
function GoogleTranslator:new()
  local obj = BaseTranslator:new('google')
  setmetatable(obj, self)
  return obj
end

--- Get service configuration
---@return I18nTranslatorServiceConfig config
function GoogleTranslator:get_config()
  local conf = config.get()
  return conf.translator.services.google or {}
end

--- Check if translator is available
---@return boolean available
---@return string|nil error
function GoogleTranslator:is_available()
  local service_config = self:get_config()

  if service_config.type == 'api' and not service_config.api_key then
    return false, 'Google Translate API key not configured'
  end

  return true, nil
end

--- Translate using free Google Translate (unofficial)
---@param text string
---@param from_lang string
---@param to_lang string
---@return string|nil translated
---@return string|nil error
function GoogleTranslator:translate_free(text, from_lang, to_lang)
  -- URL encode text
  local encoded_text = vim.uri_encode(text)

  -- Build URL for Google Translate (unofficial endpoint)
  local url = string.format(
    'https://translate.googleapis.com/translate_a/single?client=gtx&sl=%s&tl=%s&dt=t&q=%s',
    from_lang,
    to_lang,
    encoded_text
  )

  -- Make HTTP request
  local response = curl.get(url, {
    headers = {
      ['User-Agent'] = 'Mozilla/5.0',
    },
  })

  if response.status ~= 200 then
    return nil, 'HTTP error: ' .. response.status
  end

  -- Parse response (format is a nested array)
  local ok, data = pcall(vim.fn.json_decode, response.body)

  if not ok or not data or type(data) ~= 'table' then
    return nil, 'Failed to parse response'
  end

  -- Extract translated text from response
  -- Format: [[[translated_text, original_text, null, null, ...]], ...]
  if data[1] and data[1][1] and data[1][1][1] then
    local translated = ''

    for _, segment in ipairs(data[1]) do
      if segment[1] then
        translated = translated .. segment[1]
      end
    end

    return translated, nil
  end

  return nil, 'No translation found in response'
end

--- Translate using official Google Cloud Translation API
---@param text string
---@param from_lang string
---@param to_lang string
---@return string|nil translated
---@return string|nil error
function GoogleTranslator:translate_api(text, from_lang, to_lang)
  local service_config = self:get_config()

  if not service_config.api_key then
    return nil, 'API key not configured'
  end

  -- Build request URL
  local url = 'https://translation.googleapis.com/language/translate/v2?key=' .. service_config.api_key

  -- Build request body
  local body = vim.fn.json_encode({
    q = text,
    source = from_lang,
    target = to_lang,
    format = 'text',
  })

  -- Make HTTP POST request
  local response = curl.post(url, {
    headers = {
      ['Content-Type'] = 'application/json',
    },
    body = body,
  })

  if response.status ~= 200 then
    return nil, 'HTTP error: ' .. response.status
  end

  -- Parse response
  local ok, data = pcall(vim.fn.json_decode, response.body)

  if not ok or not data then
    return nil, 'Failed to parse response'
  end

  -- Extract translated text
  -- Format: { data: { translations: [{ translatedText: "..." }] } }
  if data.data and data.data.translations and data.data.translations[1] then
    return data.data.translations[1].translatedText, nil
  end

  if data.error then
    return nil, data.error.message or 'API error'
  end

  return nil, 'No translation found in response'
end

--- Translate text
---@param text string
---@param from_lang string
---@param to_lang string
---@return string|nil translated
---@return string|nil error
function GoogleTranslator:translate(text, from_lang, to_lang)
  if not text or text == '' then
    return '', nil
  end

  local service_config = self:get_config()

  if service_config.type == 'api' then
    return self:translate_api(text, from_lang, to_lang)
  else
    return self:translate_free(text, from_lang, to_lang)
  end
end

--- Translate text asynchronously with callback
---@param text string
---@param from_lang string
---@param to_lang string
---@param callback function(translated: string|nil, error: string|nil) Callback function
function GoogleTranslator:translate_async(text, from_lang, to_lang, callback)
  if not text or text == '' then
    vim.schedule(function()
      callback('', nil)
    end)
    return
  end

  local service_config = self:get_config()

  if service_config.type == 'api' then
    -- Async API translation
    local url = 'https://translation.googleapis.com/language/translate/v2?key=' .. service_config.api_key
    local body = vim.fn.json_encode({
      q = text,
      source = from_lang,
      target = to_lang,
      format = 'text',
    })

    curl.post(url, {
      headers = {
        ['Content-Type'] = 'application/json',
      },
      body = body,
      callback = function(response)
        vim.schedule(function()
          if response.status ~= 200 then
            callback(nil, 'HTTP error: ' .. response.status)
            return
          end

          local ok, data = pcall(vim.fn.json_decode, response.body)
          if not ok or not data then
            callback(nil, 'Failed to parse response')
            return
          end

          if data.data and data.data.translations and data.data.translations[1] then
            callback(data.data.translations[1].translatedText, nil)
            return
          end

          if data.error then
            callback(nil, data.error.message or 'API error')
            return
          end

          callback(nil, 'No translation found in response')
        end)
      end,
    })
  else
    -- Async free translation
    local encoded_text = vim.uri_encode(text)
    local url = string.format(
      'https://translate.googleapis.com/translate_a/single?client=gtx&sl=%s&tl=%s&dt=t&q=%s',
      from_lang,
      to_lang,
      encoded_text
    )

    curl.get(url, {
      headers = {
        ['User-Agent'] = 'Mozilla/5.0',
      },
      callback = function(response)
        vim.schedule(function()
          if response.status ~= 200 then
            callback(nil, 'HTTP error: ' .. response.status)
            return
          end

          local ok, data = pcall(vim.fn.json_decode, response.body)
          if not ok or not data or type(data) ~= 'table' then
            callback(nil, 'Failed to parse response')
            return
          end

          if data[1] and data[1][1] and data[1][1][1] then
            local translated = ''
            for _, segment in ipairs(data[1]) do
              if segment[1] then
                translated = translated .. segment[1]
              end
            end
            callback(translated, nil)
            return
          end

          callback(nil, 'No translation found in response')
        end)
      end,
    })
  end
end

--- Create and return a new instance
---@return GoogleTranslator
function M.new()
  return GoogleTranslator:new()
end

return M
