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

--- Translate a single text asynchronously with callback
---@param text string Text to translate
---@param from_lang string Source language code
---@param to_lang string Target language code
---@param callback function(translated: string|nil, error: string|nil) Callback function
---@param service? string Translator service name (defaults to config.translator.default)
function M.translate_text_async(text, from_lang, to_lang, callback, service)
  local conf = config.get()
  service = service or conf.translator.default

  local translator = get_translator(service)
  if not translator then
    vim.schedule(function()
      callback(nil, 'Translator not available: ' .. service)
    end)
    return
  end

  if translator.translate_async then
    translator:translate_async(text, from_lang, to_lang, callback)
  else
    -- Fallback to synchronous in scheduled context
    vim.schedule(function()
      local translated, err = translator:translate(text, from_lang, to_lang)
      callback(translated, err)
    end)
  end
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

--- Translate all missing translations for a key (async parallel version)
---@param key string Translation key
---@param service? string Translator service name
---@param bufnr? number Buffer number
---@param on_complete? function(success: boolean, success_count: number, total_count: number) Optional completion callback
function M.translate_missing_for_key(key, service, bufnr, on_complete)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local conf = config.get()

  -- Get missing languages
  local missing_langs = translation_source.get_missing_languages(key, bufnr)

  if #missing_langs == 0 then
    if on_complete then
      on_complete(true, 0, 0)
    end
    return
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
    -- Use key as the default source text
    source_text = key
    from_lang = conf.primary_language

    -- Get all available languages
    local all_langs = translation_source.get_languages(bufnr)

    -- Use the auto-translation function from editor module
    editor._perform_auto_translation(key, source_text, from_lang, all_langs, bufnr)

    if on_complete then
      on_complete(true, #all_langs, #all_langs)
    end
    return
  end

  -- Track completion state for parallel translations
  local completed = 0
  local success_count = 0
  local total_count = #missing_langs
  local translations = {}

  ---@param lang string
  ---@param translated string|nil
  ---@param err string|nil
  local function on_translation_complete(lang, translated, err)
    completed = completed + 1

    if translated then
      translations[lang] = translated
      success_count = success_count + 1
    else
      utils.notify('Failed to translate ' .. key .. ' to ' .. lang .. ': ' .. (err or 'Unknown error'), vim.log.levels.WARN)
    end

    -- When all translations complete, update files in batch
    if completed == total_count then
      vim.schedule(function()
        -- Prepare batch updates: lang -> { key -> translation }
        local updates = {}
        for lang, translation in pairs(translations) do
          updates[lang] = { [key] = translation }
        end

        -- Batch update all translations
        if vim.tbl_count(updates) > 0 then
          editor.batch_update_translations(updates, bufnr)

          -- Refresh virtual text and diagnostics
          local virtual_text = require('i18n.virtual_text')
          local diagnostics = require('i18n.diagnostics')
          virtual_text.refresh(bufnr)
          diagnostics.refresh(bufnr)
        end

        if on_complete then
          on_complete(success_count == total_count, success_count, total_count)
        end
      end)
    end
  end

  -- Launch all translations in parallel
  for _, to_lang in ipairs(missing_langs) do
    M.translate_text_async(source_text, from_lang, to_lang, function(translated, err)
      on_translation_complete(to_lang, translated, err)
    end, service)
  end
end

--- Translate all missing translations in buffer (async parallel version)
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

  -- Get unique keys
  local unique_keys = {}
  for _, key_location in ipairs(keys) do
    unique_keys[key_location.key] = true
  end

  -- Filter keys that have missing translations
  local keys_to_translate = {}
  for key, _ in pairs(unique_keys) do
    local missing_langs = translation_source.get_missing_languages(key, bufnr)
    if #missing_langs > 0 then
      table.insert(keys_to_translate, key)
    end
  end

  if #keys_to_translate == 0 then
    utils.notify('No missing translations found')
    return
  end

  -- Show single start message
  utils.notify('Translating ' .. #keys_to_translate .. ' keys in parallel...')

  -- Track completion of all keys
  local completed_keys = 0
  local total_keys = #keys_to_translate
  local total_translations = 0
  local successful_translations = 0

  local function on_key_complete(success, success_count, total_count)
    completed_keys = completed_keys + 1
    total_translations = total_translations + total_count
    successful_translations = successful_translations + success_count

    -- When all keys complete, show final message
    if completed_keys == total_keys then
      vim.schedule(function()
        if successful_translations == total_translations then
          utils.notify('Successfully translated ' .. total_keys .. ' keys (' .. successful_translations .. ' translations)')
        else
          utils.notify(
            string.format('Translated %d keys (%d/%d translations successful)',
              total_keys,
              successful_translations,
              total_translations
            ),
            vim.log.levels.WARN
          )
        end

        -- Final refresh
        local virtual_text = require('i18n.virtual_text')
        local diagnostics = require('i18n.diagnostics')
        virtual_text.refresh(bufnr)
        diagnostics.refresh(bufnr)
      end)
    end
  end

  -- Launch all key translations in parallel
  for _, key in ipairs(keys_to_translate) do
    M.translate_missing_for_key(key, service, bufnr, on_key_complete)
  end
end

--- Translate all missing translations in project (async parallel version)
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

  -- Filter keys that have missing translations
  local keys_to_translate = {}
  for key, _ in pairs(all_keys) do
    local missing_langs = translation_source.get_missing_languages(key, bufnr)
    if #missing_langs > 0 then
      table.insert(keys_to_translate, key)
    end
  end

  if #keys_to_translate == 0 then
    utils.notify('No missing translations found')
    return
  end

  -- Show single start message
  utils.notify('Translating ' .. #keys_to_translate .. ' keys in parallel...')

  -- Track completion of all keys
  local completed_keys = 0
  local total_keys_count = #keys_to_translate
  local total_translations = 0
  local successful_translations = 0

  local function on_key_complete(success, success_count, total_count)
    completed_keys = completed_keys + 1
    total_translations = total_translations + total_count
    successful_translations = successful_translations + success_count

    -- When all keys complete, show final message
    if completed_keys == total_keys_count then
      vim.schedule(function()
        if successful_translations == total_translations then
          utils.notify('Successfully translated ' .. total_keys_count .. ' keys (' .. successful_translations .. ' translations)')
        else
          utils.notify(
            string.format('Translated %d keys (%d/%d translations successful)',
              total_keys_count,
              successful_translations,
              total_translations
            ),
            vim.log.levels.WARN
          )
        end

        -- Refresh virtual text and diagnostics for all open buffers
        local virtual_text = require('i18n.virtual_text')
        local diagnostics = require('i18n.diagnostics')
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_loaded(buf) then
            virtual_text.refresh(buf)
            diagnostics.refresh(buf)
          end
        end
      end)
    end
  end

  -- Launch all key translations in parallel
  for _, key in ipairs(keys_to_translate) do
    M.translate_missing_for_key(key, service, bufnr, on_key_complete)
  end
end

return M
