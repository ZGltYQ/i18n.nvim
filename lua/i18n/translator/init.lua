local config = require('i18n.config')
local utils = require('i18n.utils')
local translation_source = require('i18n.translation_source')
local editor = require('i18n.editor')

local M = {}

--- Cache for translator instances
---@type table<string, BaseTranslator>
local translators = {}

--- Get translator instance by name
---@param name string Translator name ('google', 'deepl', etc.)
---@return BaseTranslator|nil translator Translator instance or nil if not found
local function get_translator(name)
  if translators[name] then
    return translators[name]
  end

  -- Try to load translator module
  local ok, translator_module = pcall(require, 'i18n.translator.' .. name)

  if not ok then
    utils.notify('Translator not found: ' .. name, vim.log.levels.ERROR)
    return nil
  end

  -- Create translator instance
  local translator = translator_module.new()

  -- Check if translator is available
  local available, err = translator:is_available()
  if not available then
    utils.notify('Translator not available: ' .. name .. ' - ' .. (err or 'Unknown error'), vim.log.levels.ERROR)
    return nil
  end

  translators[name] = translator
  return translator
end

--- Translate a single text
---@param text string Text to translate
---@param from_lang string Source language code
---@param to_lang string Target language code
---@param service? string Translator service name (defaults to config.translator.default)
---@return string|nil translated Translated text or nil on error
---@return string|nil error Error message if translation failed
function M.translate_text(text, from_lang, to_lang, service)
  local conf = config.get()
  service = service or conf.translator.default

  local translator = get_translator(service)
  if not translator then
    return nil, 'Translator not available: ' .. service
  end

  return translator:translate(text, from_lang, to_lang)
end

--- Translate a translation key for a specific language
---@param key string Translation key
---@param from_lang string Source language code
---@param to_lang string Target language code
---@param service? string Translator service name
---@param bufnr? number Buffer number
---@return boolean success True if translation was successful
function M.translate_key(key, from_lang, to_lang, service, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Get source translation
  local source_text = translation_source.get_translation(key, from_lang, bufnr)

  if not source_text then
    utils.notify('Translation not found for key: ' .. key .. ' (' .. from_lang .. ')', vim.log.levels.ERROR)
    return false
  end

  -- Translate
  local translated, err = M.translate_text(source_text, from_lang, to_lang, service)

  if not translated then
    utils.notify('Translation failed: ' .. (err or 'Unknown error'), vim.log.levels.ERROR)
    return false
  end

  -- Update translation file
  return editor.set_translation(key, to_lang, translated, bufnr)
end

--- Translate all missing translations for a key
---@param key string Translation key
---@param service? string Translator service name
---@param bufnr? number Buffer number
---@return boolean success True if all translations were successful
function M.translate_missing_for_key(key, service, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local conf = config.get()
  local from_lang = conf.primary_language

  -- Get missing languages
  local missing_langs = translation_source.get_missing_languages(key, bufnr)

  if #missing_langs == 0 then
    utils.notify('No missing translations for key: ' .. key)
    return true
  end

  utils.notify('Translating ' .. #missing_langs .. ' missing translations for key: ' .. key)

  local all_success = true

  for _, to_lang in ipairs(missing_langs) do
    local success = M.translate_key(key, from_lang, to_lang, service, bufnr)
    if not success then
      all_success = false
    end
  end

  if all_success then
    utils.notify('All translations completed for key: ' .. key)
  end

  return all_success
end

--- Translate all missing translations in buffer
---@param service? string Translator service name
---@param bufnr? number Buffer number
function M.translate_buffer(service, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local analyzer = require('i18n.analyzer')
  local keys = analyzer.get_all_keys(bufnr)

  if #keys == 0 then
    utils.notify('No translation keys found in buffer')
    return
  end

  utils.notify('Found ' .. #keys .. ' translation keys. Translating missing translations...')

  -- Get unique keys
  local unique_keys = {}
  for _, key_location in ipairs(keys) do
    unique_keys[key_location.key] = true
  end

  local translated_count = 0

  for key, _ in pairs(unique_keys) do
    local missing_langs = translation_source.get_missing_languages(key, bufnr)

    if #missing_langs > 0 then
      M.translate_missing_for_key(key, service, bufnr)
      translated_count = translated_count + 1
    end
  end

  if translated_count == 0 then
    utils.notify('No missing translations found')
  else
    utils.notify('Translated ' .. translated_count .. ' keys')

    -- Refresh virtual text
    local virtual_text = require('i18n.virtual_text')
    virtual_text.refresh(bufnr)
  end
end

--- Translate all missing translations in project
---@param service? string Translator service name
---@param bufnr? number Buffer number (for getting project root)
function M.translate_project(service, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local source = translation_source.get_source(bufnr)
  if not source then
    utils.notify('No translation source found', vim.log.levels.ERROR)
    return
  end

  utils.notify('Scanning project for missing translations...')

  -- This is a simplified implementation
  -- In a real scenario, you'd want to scan all files in the project
  -- For now, we'll just translate the current buffer
  M.translate_buffer(service, bufnr)
end

return M
