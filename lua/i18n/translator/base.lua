--- Base translator interface
--- All translators must implement the translate method

local M = {}

---@class BaseTranslator
---@field name string Translator name
local BaseTranslator = {}
BaseTranslator.__index = BaseTranslator

--- Create a new translator instance
---@param name string Translator name
---@return BaseTranslator
function BaseTranslator:new(name)
  local obj = {
    name = name,
  }
  setmetatable(obj, self)
  return obj
end

--- Translate text from one language to another
---@param text string Text to translate
---@param from_lang string Source language code (e.g., 'en', 'es')
---@param to_lang string Target language code (e.g., 'en', 'es')
---@return string|nil translated Translated text or nil on error
---@return string|nil error Error message if translation failed
function BaseTranslator:translate(text, from_lang, to_lang)
  error('translate() must be implemented by subclass')
end

--- Batch translate multiple texts
---@param texts string[] Texts to translate
---@param from_lang string Source language code
---@param to_lang string Target language code
---@return table<number, string> translations Map of index to translated text
---@return table<number, string> errors Map of index to error message
function BaseTranslator:batch_translate(texts, from_lang, to_lang)
  local translations = {}
  local errors = {}

  for i, text in ipairs(texts) do
    local translated, err = self:translate(text, from_lang, to_lang)

    if translated then
      translations[i] = translated
    else
      errors[i] = err or 'Unknown error'
    end
  end

  return translations, errors
end

--- Check if translator is available (API key configured, etc.)
---@return boolean available
---@return string|nil error Error message if not available
function BaseTranslator:is_available()
  return true, nil
end

M.BaseTranslator = BaseTranslator

return M
