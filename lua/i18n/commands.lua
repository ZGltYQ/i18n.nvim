local config = require('i18n.config')
local utils = require('i18n.utils')
local virtual_text = require('i18n.virtual_text')
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

  translator.translate_buffer(service)
end

--- Translate all missing keys in project
---@param args table Command arguments
local function translate_all(args)
  local service = args.args

  if service == '' then
    service = nil -- Use default service
  end

  translator.translate_project(service)
end

--- Translate a specific key
---@param args table Command arguments
local function translate_key(args)
  local parts = vim.split(args.args, ' ', { trimempty = true })

  if #parts < 3 then
    utils.notify('Usage: I18nTranslateKey <key> <from_lang> <to_lang> [service]', vim.log.levels.ERROR)
    return
  end

  local key = parts[1]
  local from_lang = parts[2]
  local to_lang = parts[3]
  local service = parts[4]

  translator.translate_key(key, from_lang, to_lang, service)
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

--- Reload translation files
local function reload(args)
  translation_source.reload()
  utils.notify('Translation files reloaded')

  -- Refresh virtual text for all buffers
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if virtual_text.is_enabled(bufnr) then
      virtual_text.refresh(bufnr)
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

  local width = 60
  local height = #lines + 2

  local win = vim.api.nvim_open_win(buf, false, {
    relative = 'cursor',
    width = width,
    height = height,
    row = 1,
    col = 0,
    style = 'minimal',
    border = 'rounded',
  })

  -- Close on any key press
  vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', '', {
    callback = function()
      vim.api.nvim_win_close(win, true)
    end,
  })

  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '', {
    callback = function()
      vim.api.nvim_win_close(win, true)
    end,
  })
end

--- Add translation from selected text
local function add_from_selection(args)
  editor.add_from_selection(args.buf)
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

  vim.api.nvim_create_user_command('I18nTranslateAll', translate_all, {
    nargs = '?',
    desc = 'Auto-translate all missing keys in project',
  })

  vim.api.nvim_create_user_command('I18nTranslateKey', translate_key, {
    nargs = '+',
    desc = 'Translate a specific key',
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
end

return M
