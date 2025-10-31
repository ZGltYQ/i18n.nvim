local config = require('i18n.config')
local utils = require('i18n.utils')
local translation_source = require('i18n.translation_source')

local M = {}

--- Update JSON file using jq (if available) or fallback to Lua
---@param file_path string File path
---@param key_parts string[] Translation key parts
---@param value string Translation value
---@return boolean success True if update was successful
local function update_json_file(file_path, key_parts, value)
  -- Try using jq for reliable JSON manipulation
  if utils.command_exists('jq') then
    -- Build jq path expression
    local jq_path = table.concat(vim.tbl_map(function(part)
      return '["' .. part .. '"]'
    end, key_parts))

    -- Escape value for shell
    local escaped_value = value:gsub('"', '\\"')

    -- Use jq to update the file
    local cmd = string.format('jq \'%s = "%s"\' %s > %s.tmp && mv %s.tmp %s', jq_path, escaped_value, file_path,
      file_path, file_path, file_path)

    local result = vim.fn.system(cmd)

    if vim.v.shell_error == 0 then
      return true
    end

    utils.notify('jq failed, falling back to Lua JSON update', vim.log.levels.WARN)
  end

  -- Fallback to Lua implementation
  local ok, content = pcall(function()
    local lines = vim.fn.readfile(file_path)
    return vim.fn.json_decode(table.concat(lines, '\n'))
  end)

  if not ok then
    utils.notify('Failed to parse JSON file: ' .. file_path, vim.log.levels.ERROR)
    return false
  end

  -- Set the value
  utils.tbl_set(content, key_parts, value)

  -- Write back
  local json = vim.fn.json_encode(content)
  vim.fn.writefile(vim.split(json, '\n'), file_path)

  return true
end

--- Update YAML file using yq (if available)
---@param file_path string File path
---@param key_parts string[] Translation key parts
---@param value string Translation value
---@return boolean success True if update was successful
local function update_yaml_file(file_path, key_parts, value)
  if not utils.command_exists('yq') then
    utils.notify('yq command not found. Cannot update YAML files.', vim.log.levels.ERROR)
    return false
  end

  -- Build yq path expression
  local yq_path = '.' .. table.concat(key_parts, '.')

  -- Escape value for shell
  local escaped_value = value:gsub('"', '\\"')

  -- Use yq to update the file
  local cmd = string.format('yq eval \'%s = "%s"\' -i %s', yq_path, escaped_value, file_path)

  local result = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    utils.notify('Failed to update YAML file: ' .. file_path, vim.log.levels.ERROR)
    return false
  end

  return true
end

--- Update translation file
---@param file_path string File path
---@param key_parts string[] Translation key parts
---@param value string Translation value
---@return boolean success True if update was successful
local function update_file(file_path, key_parts, value)
  local ext = vim.fn.fnamemodify(file_path, ':e')

  if ext == 'json' then
    return update_json_file(file_path, key_parts, value)
  elseif ext == 'yml' or ext == 'yaml' then
    return update_yaml_file(file_path, key_parts, value)
  end

  utils.notify('Unsupported file format: ' .. ext, vim.log.levels.ERROR)
  return false
end

--- Edit translation for a specific key and language
---@param key string Translation key
---@param lang string Language code
---@param value string Translation value
---@param bufnr? number Buffer number
---@return boolean success True if update was successful
function M.set_translation(key, lang, value, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local source = translation_source.get_source(bufnr)
  if not source then
    utils.notify('No translation source found', vim.log.levels.ERROR)
    return false
  end

  local file = source.files[lang]
  if not file then
    utils.notify('Translation file not found for language: ' .. lang, vim.log.levels.ERROR)
    return false
  end

  local conf = config.get()
  local key_parts = utils.split_key(key, conf.key_separator)

  -- Update the file
  local success = update_file(file.path, key_parts, value)

  if success then
    -- Reload translation source
    translation_source.reload(source.root_dir)
    utils.notify('Translation updated: ' .. key .. ' (' .. lang .. ')')
    return true
  end

  return false
end

--- Edit translation at cursor position
---@param lang? string Language code (defaults to primary language)
---@param bufnr? number Buffer number
function M.edit_at_cursor(lang, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local conf = config.get()
  lang = lang or conf.primary_language

  -- Get translation key at cursor
  local analyzer = require('i18n.analyzer')
  local key = analyzer.get_key_at_position(bufnr)

  if not key then
    utils.notify('No translation key found at cursor', vim.log.levels.WARN)
    return
  end

  -- Get current translation
  local current_translation = translation_source.get_translation(key, lang, bufnr)

  -- Prompt for new translation
  vim.ui.input({
    prompt = string.format('Edit translation [%s] (%s): ', key, lang),
    default = current_translation or '',
  }, function(input)
    if not input then
      return
    end

    M.set_translation(key, lang, input, bufnr)

    -- Refresh virtual text
    local virtual_text = require('i18n.virtual_text')
    virtual_text.refresh(bufnr)
  end)
end

--- Add translation to all language files
---@param key string Translation key
---@param translations table<string, string> Map of language to translation
---@param bufnr? number Buffer number
---@return boolean success True if all updates were successful
function M.add_translation(key, translations, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local source = translation_source.get_source(bufnr)
  if not source then
    utils.notify('No translation source found', vim.log.levels.ERROR)
    return false
  end

  local conf = config.get()
  local key_parts = utils.split_key(key, conf.key_separator)
  local all_success = true

  -- Update each language file
  for lang, value in pairs(translations) do
    local file = source.files[lang]

    if file then
      local success = update_file(file.path, key_parts, value)
      if not success then
        all_success = false
      end
    else
      utils.notify('No translation file for language: ' .. lang, vim.log.levels.WARN)
      all_success = false
    end
  end

  if all_success then
    -- Reload translation source
    translation_source.reload(source.root_dir)
    utils.notify('Translation added: ' .. key)
  end

  return all_success
end

--- Delete translation from all language files
---@param key string Translation key
---@param bufnr? number Buffer number
---@return boolean success True if deletion was successful
function M.delete_translation(key, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local source = translation_source.get_source(bufnr)
  if not source then
    utils.notify('No translation source found', vim.log.levels.ERROR)
    return false
  end

  local conf = config.get()
  local key_parts = utils.split_key(key, conf.key_separator)

  -- For simplicity, we'll use jq/yq to delete keys
  for lang, file in pairs(source.files) do
    local ext = vim.fn.fnamemodify(file.path, ':e')

    if ext == 'json' and utils.command_exists('jq') then
      local jq_path = table.concat(vim.tbl_map(function(part)
        return '["' .. part .. '"]'
      end, key_parts))

      local cmd = string.format('jq \'del(%s)\' %s > %s.tmp && mv %s.tmp %s', jq_path, file.path, file.path,
        file.path, file.path)

      vim.fn.system(cmd)
    elseif (ext == 'yml' or ext == 'yaml') and utils.command_exists('yq') then
      local yq_path = '.' .. table.concat(key_parts, '.')
      local cmd = string.format('yq eval \'del(%s)\' -i %s', yq_path, file.path)
      vim.fn.system(cmd)
    end
  end

  -- Reload translation source
  translation_source.reload(source.root_dir)
  utils.notify('Translation deleted: ' .. key)

  return true
end

--- Add translation from selected text with auto-translation to all languages
---@param bufnr? number Buffer number
function M.add_from_selection(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Get selected text
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line = start_pos[2]
  local start_col = start_pos[3]
  local end_line = end_pos[2]
  local end_col = end_pos[3]

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

  if #lines == 0 then
    utils.notify('No text selected', vim.log.levels.WARN)
    return
  end

  -- Extract selected text
  local selected_text
  if #lines == 1 then
    selected_text = lines[1]:sub(start_col, end_col)
  else
    lines[1] = lines[1]:sub(start_col)
    lines[#lines] = lines[#lines]:sub(1, end_col)
    selected_text = table.concat(lines, ' ')
  end

  selected_text = vim.trim(selected_text)

  if selected_text == '' then
    utils.notify('No text selected', vim.log.levels.WARN)
    return
  end

  -- Get translation source to check available languages
  local source = translation_source.get_source(bufnr)
  if not source then
    utils.notify('No translation source found', vim.log.levels.ERROR)
    return
  end

  local languages = vim.tbl_keys(source.files)
  if #languages == 0 then
    utils.notify('No translation files found', vim.log.levels.ERROR)
    return
  end

  local conf = config.get()
  local primary_lang = conf.primary_language

  -- Prompt for translation key
  vim.ui.input({
    prompt = string.format('Translation key for "%s": ',
      utils.truncate(selected_text, 30)),
    default = '',
  }, function(key)
    if not key or key == '' then
      return
    end

    -- Check if key already exists
    if translation_source.key_exists(key, bufnr) then
      vim.ui.select({ 'Yes', 'No' }, {
        prompt = 'Key "' .. key .. '" already exists. Overwrite?',
      }, function(choice)
        if choice ~= 'Yes' then
          return
        end
        -- Continue with translation
        M._perform_auto_translation(key, selected_text, primary_lang, languages, bufnr)
      end)
    else
      -- Continue with translation
      M._perform_auto_translation(key, selected_text, primary_lang, languages, bufnr)
    end
  end)
end

--- Internal function to perform auto-translation
---@param key string Translation key
---@param source_text string Source text to translate from
---@param source_lang string Source language code
---@param languages string[] All language codes
---@param bufnr number Buffer number
function M._perform_auto_translation(key, source_text, source_lang, languages, bufnr)
  local translator = require('i18n.translator')
  local translations = {}

  -- Add source language translation
  translations[source_lang] = source_text

  utils.notify('Translating to ' .. (#languages - 1) .. ' languages...')

  -- Count successful translations
  local success_count = 0
  local total_count = 0

  -- Translate to all other languages
  for _, lang in ipairs(languages) do
    if lang ~= source_lang then
      total_count = total_count + 1

      local translated, err = translator.translate_text(source_text, source_lang, lang)

      if translated then
        translations[lang] = translated
        success_count = success_count + 1
      else
        utils.notify('Failed to translate to ' .. lang .. ': ' .. (err or 'Unknown error'), vim.log.levels.WARN)
        -- Use source text as fallback
        translations[lang] = source_text
      end
    end
  end

  -- Add all translations to files
  local add_success = M.add_translation(key, translations, bufnr)

  if add_success then
    utils.notify(string.format(
      'Translation added: %s (%d/%d languages translated successfully)',
      key,
      success_count,
      total_count
    ))

    -- Refresh virtual text
    local virtual_text = require('i18n.virtual_text')
    virtual_text.refresh(bufnr)
  end
end

return M
