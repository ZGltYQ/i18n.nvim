local config = require('i18n.config')
local utils = require('i18n.utils')
local virtual_text = require('i18n.virtual_text')
local diagnostics = require('i18n.diagnostics')
local editor = require('i18n.editor')
local translator = require('i18n.translator')
local translation_source = require('i18n.translation_source')
local analyzer = require('i18n.analyzer')

local M = {}

--- Set primary display language
---@param args table Command arguments
local function set_lang(args)
  local lang = args.args

  if not lang or lang == '' then
    utils.notify('Usage: I18nSetLang <language>', vim.log.levels.ERROR)
    return
  end

  config.set('primary_language', lang)
  utils.notify('Primary language set to: ' .. lang)

  -- Refresh virtual text for all buffers
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if virtual_text.is_enabled(bufnr) then
      virtual_text.refresh(bufnr)
    end
  end
end

--- Edit translation at cursor
---@param args table Command arguments
local function edit_translation(args)
  local lang = args.args

  if lang == '' then
    lang = nil -- Use primary language
  end

  editor.edit_at_cursor(lang)
end

--- Translate missing keys in buffer
---@param args table Command arguments
local function translate_buffer(args)
  local service = args.args

  if service == '' then
    service = nil -- Use default service
  end

  -- Check if there are any translation keys in the buffer
  local keys = analyzer.get_all_keys(args.buf)

  if #keys > 0 then
    -- There are keys, translate missing translations
    translator.translate_buffer(service, args.buf)
  else
    -- No keys in buffer, offer to create translation from word under cursor
    utils.notify('No translation keys found in buffer', vim.log.levels.WARN)

    -- Get word under cursor
    local word = vim.fn.expand('<cword>')

    if word == '' then
      utils.notify('No word under cursor. Use visual selection or move cursor to a word.', vim.log.levels.WARN)
      return
    end

    -- Ask for translation key
    vim.ui.input({
      prompt = string.format('Create translation key for "%s": ', word),
      default = '',
    }, function(key)
      if not key or key == '' then
        return
      end

      -- Get available languages
      local source = translation_source.get_source(args.buf)
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

      -- Use editor._perform_auto_translation to create and translate
      editor._perform_auto_translation(key, word, primary_lang, languages, args.buf)
    end)
  end
end

--- Translate key at cursor position to all missing languages
---@param args table Command arguments
local function translate_key_at_cursor(args)
  local service = args.args

  if service == '' then
    service = nil -- Use default service
  end

  -- Get key at cursor
  local key = analyzer.get_key_at_position(args.buf)

  if not key then
    utils.notify('No translation key found at cursor', vim.log.levels.WARN)
    return
  end

  -- Translate to all missing languages
  translator.translate_missing_for_key(key, service, args.buf)
end

--- Enable virtual text
local function virtual_text_enable(args)
  virtual_text.enable(args.buf)
end

--- Disable virtual text
local function virtual_text_disable(args)
  virtual_text.disable(args.buf)
end

--- Toggle virtual text
local function virtual_text_toggle(args)
  virtual_text.toggle(args.buf)
end

--- Enable diagnostics
local function diagnostics_enable(args)
  diagnostics.enable(args.buf)
end

--- Disable diagnostics
local function diagnostics_disable(args)
  diagnostics.disable(args.buf)
end

--- Toggle diagnostics
local function diagnostics_toggle(args)
  diagnostics.toggle(args.buf)
end

--- Reload translation files
local function reload(args)
  translation_source.reload()
  utils.notify('Translation files reloaded')

  -- Refresh virtual text and diagnostics for all buffers
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if virtual_text.is_enabled(bufnr) then
      virtual_text.refresh(bufnr)
    end
    if diagnostics.is_enabled(bufnr) then
      diagnostics.refresh(bufnr)
    end
  end
end

--- Copy translation key at cursor
local function copy_key(args)
  local key = analyzer.get_key_at_position(args.buf)

  if not key then
    utils.notify('No translation key found at cursor', vim.log.levels.WARN)
    return
  end

  vim.fn.setreg('+', key)
  vim.fn.setreg('"', key)
  utils.notify('Copied to clipboard: ' .. key)
end

--- Get all available languages
local function list_languages(args)
  local languages = translation_source.get_languages(args.buf)

  if #languages == 0 then
    utils.notify('No translation files found', vim.log.levels.WARN)
    return
  end

  utils.notify('Available languages: ' .. table.concat(languages, ', '))
end

--- Show translation info for key at cursor
local function show_info(args)
  local key = analyzer.get_key_at_position(args.buf)

  if not key then
    utils.notify('No translation key found at cursor', vim.log.levels.WARN)
    return
  end

  local translations = translation_source.get_all_translations(key, args.buf)

  if vim.tbl_isempty(translations) then
    utils.notify('No translations found for key: ' .. key, vim.log.levels.WARN)
    return
  end

  -- Build info message
  local lines = { 'Translations for: ' .. key, '' }

  for lang, text in pairs(translations) do
    table.insert(lines, string.format('  [%s] %s', lang, text))
  end

  -- Show in floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = 'wipe'

  local width = 60
  local height = #lines + 2

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'cursor',
    width = width,
    height = height,
    row = 1,
    col = 0,
    style = 'minimal',
    border = 'rounded',
  })

  -- Close on any key press
  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, nowait = true })

  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, nowait = true })

  -- Close when leaving the window
  vim.api.nvim_create_autocmd({ 'BufLeave', 'WinLeave' }, {
    buffer = buf,
    once = true,
    callback = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end,
  })
end

--- Add translation from selected text
local function add_from_selection(args)
  editor.add_from_selection(args.buf)
end

--- Debug: Show all loaded keys from translation files
local function debug_keys(args)
  local source = translation_source.get_source(args.buf)
  if not source then
    utils.notify('No translation source found', vim.log.levels.ERROR)
    return
  end

  -- Collect all unique keys
  local all_keys = {}
  for lang, file in pairs(source.files) do
    local function collect_keys(tbl, prefix)
      for key, value in pairs(tbl) do
        local full_key = prefix == '' and key or (prefix .. '.' .. key)
        if type(value) == 'table' then
          collect_keys(value, full_key)
        else
          if not all_keys[full_key] then
            all_keys[full_key] = {}
          end
          all_keys[full_key][lang] = true
        end
      end
    end
    collect_keys(file.content, '')
  end

  -- Build message
  local lines = { 'All Translation Keys:', '' }
  local sorted_keys = vim.tbl_keys(all_keys)
  table.sort(sorted_keys)

  for _, key in ipairs(sorted_keys) do
    local langs = vim.tbl_keys(all_keys[key])
    table.sort(langs)
    table.insert(lines, string.format('  %s [%s]', key, table.concat(langs, ', ')))
  end

  if #sorted_keys == 0 then
    table.insert(lines, '  No keys found!')
  end

  table.insert(lines, '')
  table.insert(lines, string.format('Total: %d keys', #sorted_keys))

  -- Show in floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = 'wipe'

  local width = 80
  local height = math.min(#lines + 2, 30)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = 2,
    col = (vim.o.columns - width) / 2,
    style = 'minimal',
    border = 'rounded',
  })

  -- Close on any key press
  vim.keymap.set('n', '<Esc>', function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, nowait = true })

  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, nowait = true })

  -- Close when leaving the window
  vim.api.nvim_create_autocmd({ 'BufLeave', 'WinLeave' }, {
    buffer = buf,
    once = true,
    callback = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end,
  })
end

--- Create user commands
function M.setup()
  vim.api.nvim_create_user_command('I18nSetLang', set_lang, {
    nargs = 1,
    desc = 'Set primary language for virtual text display',
  })

  vim.api.nvim_create_user_command('I18nEdit', edit_translation, {
    nargs = '?',
    desc = 'Edit translation at cursor position',
  })

  vim.api.nvim_create_user_command('I18nTranslate', translate_buffer, {
    nargs = '?',
    desc = 'Auto-translate missing keys in current buffer',
  })

  vim.api.nvim_create_user_command('I18nTranslateKey', translate_key_at_cursor, {
    nargs = '?',
    desc = 'Auto-translate key at cursor to all missing languages',
  })

  vim.api.nvim_create_user_command('I18nVirtualTextEnable', virtual_text_enable, {
    desc = 'Enable virtual text display',
  })

  vim.api.nvim_create_user_command('I18nVirtualTextDisable', virtual_text_disable, {
    desc = 'Disable virtual text display',
  })

  vim.api.nvim_create_user_command('I18nVirtualTextToggle', virtual_text_toggle, {
    desc = 'Toggle virtual text display',
  })

  vim.api.nvim_create_user_command('I18nDiagnosticsEnable', diagnostics_enable, {
    desc = 'Enable LSP diagnostics for missing translations',
  })

  vim.api.nvim_create_user_command('I18nDiagnosticsDisable', diagnostics_disable, {
    desc = 'Disable LSP diagnostics for missing translations',
  })

  vim.api.nvim_create_user_command('I18nDiagnosticsToggle', diagnostics_toggle, {
    desc = 'Toggle LSP diagnostics for missing translations',
  })

  vim.api.nvim_create_user_command('I18nReload', reload, {
    desc = 'Reload translation files from disk',
  })

  vim.api.nvim_create_user_command('I18nCopyKey', copy_key, {
    desc = 'Copy translation key at cursor to clipboard',
  })

  vim.api.nvim_create_user_command('I18nListLanguages', list_languages, {
    desc = 'List all available languages',
  })

  vim.api.nvim_create_user_command('I18nInfo', show_info, {
    desc = 'Show translation info for key at cursor',
  })

  vim.api.nvim_create_user_command('I18nAddFromSelection', add_from_selection, {
    range = true,
    desc = 'Add translation from selected text and auto-translate to all languages',
  })

  vim.api.nvim_create_user_command('I18nDebugKeys', debug_keys, {
    desc = 'Debug: Show all loaded translation keys',
  })
end

return M
