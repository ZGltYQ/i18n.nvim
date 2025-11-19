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

  -- Get missing languages
  local missing_langs = translation_source.get_missing_languages(key, bufnr)

  if #missing_langs == 0 then
    utils.notify('No missing translations for key: ' .. key)
    return true
  end

  -- Find a source language that has this translation
  -- Try primary language first, then any other language
  local from_lang = nil
  local source_text = translation_source.get_translation(key, conf.primary_language, bufnr)

  if source_text then
    from_lang = conf.primary_language
  else
    -- Primary language doesn't have it, find any language that does
    local all_translations = translation_source.get_all_translations(key, bufnr)
    for lang, text in pairs(all_translations) do
      from_lang = lang
      source_text = text
      break
    end
  end

  if not from_lang or not source_text then
    -- No source translation found, use the key name as default translation
    -- and auto-add it to all language files
    utils.notify('No source translation found for key: ' .. key .. '. Auto-creating with key name as default...')

    -- Use key as the default source text
    source_text = key
    from_lang = conf.primary_language

    -- Get all available languages
    local all_langs = translation_source.get_languages(bufnr)

    -- Use the auto-translation function from editor module
    editor._perform_auto_translation(key, source_text, from_lang, all_langs, bufnr)

    return true
  end

  utils.notify('Translating ' .. #missing_langs .. ' missing translations for key: ' .. key .. ' (from ' .. from_lang .. ')')

  local all_success = true

  for _, to_lang in ipairs(missing_langs) do
    local success = M.translate_key(key, from_lang, to_lang, service, bufnr)
    if not success then
      all_success = false
    end
  end

  if all_success then
    utils.notify('All translations completed for key: ' .. key)

    -- Refresh virtual text and diagnostics
    local virtual_text = require('i18n.virtual_text')
    local diagnostics = require('i18n.diagnostics')
    virtual_text.refresh(bufnr)
    diagnostics.refresh(bufnr)
  end

  return all_success
end

--- Translate all missing translations in buffer
---@param service? string Translator service name
---@param bufnr? number Buffer number
function M.translate_buffer(service, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Reload translation source to ensure fresh data
  translation_source.reload()

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

    -- Refresh virtual text and diagnostics
    local virtual_text = require('i18n.virtual_text')
    local diagnostics = require('i18n.diagnostics')
    virtual_text.refresh(bufnr)
    diagnostics.refresh(bufnr)
  end
end

--- Translate all missing translations in project
---@param service? string Translator service name
---@param bufnr? number Buffer number (for getting project root)
function M.translate_project(service, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Reload translation source to ensure fresh data
  translation_source.reload()

  local source = translation_source.get_source(bufnr)
  if not source then
    utils.notify('No translation source found', vim.log.levels.ERROR)
    return
  end

  utils.notify('Scanning project for missing translations...')

  -- Get all unique keys from all translation files
  local all_keys = {}
  for lang, file in pairs(source.files) do
    local function collect_keys(tbl, prefix)
      for key, value in pairs(tbl) do
        local full_key = prefix == '' and key or (prefix .. '.' .. key)
        if type(value) == 'table' then
          collect_keys(value, full_key)
        else
          all_keys[full_key] = true
        end
      end
    end
    collect_keys(file.content, '')
  end

  local total_keys = vim.tbl_count(all_keys)
  if total_keys == 0 then
    utils.notify('No translation keys found in project')
    return
  end

  utils.notify('Found ' .. total_keys .. ' translation keys. Translating missing translations...')

  local translated_count = 0
  for key, _ in pairs(all_keys) do
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

    -- Refresh virtual text and diagnostics for all open buffers
    local virtual_text = require('i18n.virtual_text')
    local diagnostics = require('i18n.diagnostics')
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then
        virtual_text.refresh(buf)
        diagnostics.refresh(buf)
      end
    end
  end
end

return M
