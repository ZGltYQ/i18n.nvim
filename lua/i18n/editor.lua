local config = require('i18n.config')
local utils = require('i18n.utils')
local translation_source = require('i18n.translation_source')

local M = {}

--- Update JSON file with flat keys while preserving order
---@param file_path string File path
---@param updates table<string, string> Map of keys to values
---@return boolean success True if update was successful
local function update_json_flat_preserving_order(file_path, updates)
  -- Read existing file
  local ok, lines = pcall(vim.fn.readfile, file_path)

  if not ok or #lines == 0 then
    -- Create new file with updates
    local content = {'{'}
    local keys = vim.tbl_keys(updates)
    for i, key in ipairs(keys) do
      local comma = (i < #keys) and ',' or ''
      table.insert(content, '  "' .. key:gsub('"', '\\"') .. '": "' .. updates[key]:gsub('"', '\\"') .. '"' .. comma)
    end
    table.insert(content, '}')
    vim.fn.writefile(content, file_path)
    return true
  end

  -- Track which keys we've processed
  local processed = {}

  -- Update existing keys in-place
  for i, line in ipairs(lines) do
    -- Match JSON key in this line (handles escaped quotes in keys)
    local key_match = line:match('^%s*"(.-[^\\])"%s*:')
    if not key_match then
      -- Try to match key without escapes
      key_match = line:match('^%s*"(.-)"%s*:')
    end

    if key_match then
      -- Unescape the key to match against updates
      local key = key_match:gsub('\\"', '"')

      if updates[key] then
        -- Update this key's value while preserving indentation and comma
        local indent = line:match('^(%s*)')
        local has_comma = line:match(',$') ~= nil
        local comma = has_comma and ',' or ''
        lines[i] = indent .. '"' .. key:gsub('"', '\\"') .. '": "' .. updates[key]:gsub('"', '\\"') .. '"' .. comma
        processed[key] = true
      end
    end
  end

  -- Collect new keys that weren't in the original file
  local new_keys = {}
  for key, value in pairs(updates) do
    if not processed[key] then
      table.insert(new_keys, {key = key, value = value})
    end
  end

  -- Add new keys at the end (before closing brace)
  if #new_keys > 0 then
    -- Find the closing brace line
    for i = #lines, 1, -1 do
      if lines[i]:match('^%s*}%s*$') then
        -- Find the last non-empty, non-brace line before closing brace
        local last_entry_line = i - 1
        while last_entry_line > 0 and (lines[last_entry_line]:match('^%s*$') or lines[last_entry_line]:match('^%s*}')) do
          last_entry_line = last_entry_line - 1
        end

        -- Add comma to last entry if it doesn't have one and isn't the opening brace
        if last_entry_line > 0 and not lines[last_entry_line]:match(',$') and not lines[last_entry_line]:match('^%s*{') then
          lines[last_entry_line] = lines[last_entry_line] .. ','
        end

        -- Insert new keys before the closing brace
        for j, entry in ipairs(new_keys) do
          local comma = (j < #new_keys) and ',' or ''
          table.insert(lines, i, '  "' .. entry.key:gsub('"', '\\"') .. '": "' .. entry.value:gsub('"', '\\"') .. '"' .. comma)
          i = i + 1
        end
        break
      end
    end
  end

  -- Write back to file
  vim.fn.writefile(lines, file_path)
  return true
end

--- Update JSON file with flat keys (no nesting)
---@param file_path string File path
---@param key string Translation key (treated as single flat key, not split)
---@param value string Translation value
---@return boolean success True if update was successful
local function update_json_file(file_path, key, value)
  -- Use the new flat key preserving order function
  return update_json_flat_preserving_order(file_path, {[key] = value})
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
---@param key string Translation key (for JSON: flat key; for YAML: may be split)
---@param value string Translation value
---@return boolean success True if update was successful
local function update_file(file_path, key, value)
  local ext = vim.fn.fnamemodify(file_path, ':e')

  if ext == 'json' then
    -- JSON: use flat key (no splitting)
    return update_json_file(file_path, key, value)
  elseif ext == 'yml' or ext == 'yaml' then
    -- YAML: split key for nested structure
    local conf = config.get()
    local key_parts = utils.split_key(key, conf.key_separator)
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

  -- Update the file with flat key (no splitting)
  local success = update_file(file.path, key, value)

  if success then
    -- Reload translation source
    translation_source.reload(source.root_dir)
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

    -- Refresh virtual text and diagnostics
    local virtual_text = require('i18n.virtual_text')
    local diagnostics = require('i18n.diagnostics')
    virtual_text.refresh(bufnr)
    diagnostics.refresh(bufnr)
  end)
end

--- Update multiple translations in batch (one file write per language)
---@param updates table<string, table<string, string>> Map of language to map of key to translation
---@param bufnr? number Buffer number
---@return boolean success True if all updates were successful
function M.batch_update_translations(updates, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local source = translation_source.get_source(bufnr)
  if not source then
    utils.notify('No translation source found', vim.log.levels.ERROR)
    return false
  end

  local conf = config.get()
  local all_success = true

  -- Update each language file once with all translations
  for lang, key_values in pairs(updates) do
    local file = source.files[lang]

    if file then
      local ext = vim.fn.fnamemodify(file.path, ':e')

      -- For JSON files, batch all updates with flat keys preserving order
      if ext == 'json' then
        local success = update_json_flat_preserving_order(file.path, key_values)
        if not success then
          utils.notify('Failed to update JSON file: ' .. file.path, vim.log.levels.ERROR)
          all_success = false
        end
      elseif ext == 'yml' or ext == 'yaml' then
        -- For YAML files, still need to use yq per key (limitation of current approach)
        -- TODO: Could be improved with a Lua YAML library
        for key, value in pairs(key_values) do
          local key_parts = utils.split_key(key, conf.key_separator)
          local success = update_yaml_file(file.path, key_parts, value)
          if not success then
            all_success = false
          end
        end
      end
    else
      utils.notify('No translation file for language: ' .. lang, vim.log.levels.WARN)
      all_success = false
    end
  end

  if all_success then
    -- Reload translation source once at the end (silently to avoid duplicate notifications)
    translation_source.reload(source.root_dir, true)
  end

  return all_success
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

  local all_success = true

  -- Update each language file with flat key (no splitting)
  for lang, value in pairs(translations) do
    local file = source.files[lang]

    if file then
      local success = update_file(file.path, key, value)
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

      local cmd = string.format('jq --indent 2 \'del(%s)\' %s > %s.tmp && mv %s.tmp %s', jq_path, file.path, file.path,
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

--- Internal function to perform auto-translation (parallel version)
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

  -- Build list of target languages (exclude source)
  local target_langs = {}
  for _, lang in ipairs(languages) do
    if lang ~= source_lang then
      table.insert(target_langs, lang)
    end
  end

  if #target_langs == 0 then
    -- No translations needed, just add source
    M.add_translation(key, translations, bufnr)
    utils.notify('Translation added: ' .. key)
    return
  end

  utils.notify(string.format('Translating to %d languages in parallel...', #target_langs))

  -- Track completion state
  local completed = 0
  local success_count = 0
  local total_count = #target_langs

  ---@param lang string
  ---@param result string|nil
  ---@param err string|nil
  local function on_translation_complete(lang, result, err)
    completed = completed + 1

    if result then
      translations[lang] = result
      success_count = success_count + 1
    else
      utils.notify('Failed to translate to ' .. lang .. ': ' .. (err or 'Unknown error'), vim.log.levels.WARN)
      -- Use source text as fallback
      translations[lang] = source_text
    end

    -- When all translations complete, add them to files
    if completed == total_count then
      vim.schedule(function()
        local add_success = M.add_translation(key, translations, bufnr)

        if add_success then
          utils.notify(string.format(
            'Translation added: %s (%d/%d languages translated successfully)',
            key,
            success_count,
            total_count
          ))

          -- Refresh virtual text and diagnostics
          local virtual_text = require('i18n.virtual_text')
          local diagnostics = require('i18n.diagnostics')
          virtual_text.refresh(bufnr)
          diagnostics.refresh(bufnr)
        end
      end)
    end
  end

  -- Launch all translations in parallel
  for _, lang in ipairs(target_langs) do
    -- Use vim.schedule to ensure async execution
    vim.schedule(function()
      local translated, err = translator.translate_text(source_text, source_lang, lang)
      on_translation_complete(lang, translated, err)
    end)
  end
end

return M
