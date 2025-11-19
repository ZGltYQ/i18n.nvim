--- i18n.nvim - Neovim plugin for i18next with auto-translation

local M = {}

--- Check if plugin has been initialized
local initialized = false

--- Setup the plugin
---@param opts? I18nConfig User configuration
function M.setup(opts)
  if initialized then
    return
  end

  -- Setup configuration
  local config = require('i18n.config')
  config.setup(opts or {})

  -- Create user commands
  local commands = require('i18n.commands')
  commands.setup()

  -- Load modules (will be enabled automatically for JS/TS buffers via FileType autocmd)
  local virtual_text = require('i18n.virtual_text')
  local diagnostics = require('i18n.diagnostics')

  -- Set up autocommands
  local group = vim.api.nvim_create_augroup('i18n', { clear = true })

  -- Enable virtual text and diagnostics for new JavaScript/TypeScript buffers
  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = { 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' },
    callback = function(args)
      local conf = config.get()
      vim.defer_fn(function()
        if conf.virtual_text.enabled then
          virtual_text.enable(args.buf)
        end
        if conf.diagnostic.enabled then
          diagnostics.enable(args.buf)
        end
      end, 100) -- Small delay to ensure treesitter is loaded
    end,
  })

  -- Watch for changes to translation files and external file changes
  vim.api.nvim_create_autocmd({ 'BufWritePost', 'FileChangedShellPost' }, {
    group = group,
    pattern = { '*.json', '*.yml', '*.yaml' },
    callback = function(args)
      -- Check if this is a translation file by checking the path
      local file_path = vim.api.nvim_buf_get_name(args.buf)
      local conf = config.get()

      -- Check if file matches any translation source pattern
      local is_translation_file = false
      for _, pattern in ipairs(conf.translation_source) do
        -- Simple pattern matching - check if path contains common translation directories
        if file_path:match('/locales/') or
           file_path:match('/translations/') or
           file_path:match('/i18n/') or
           file_path:match('/lang/') then
          is_translation_file = true
          break
        end
      end

      if is_translation_file then
        -- Reload translation source (now uses incremental mtime checking)
        local translation_source = require('i18n.translation_source')
        translation_source.reload()

        -- Refresh virtual text and diagnostics only for visible JS/TS buffers
        vim.schedule(function()
          for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_loaded(bufnr) then
              local ft = vim.bo[bufnr].filetype
              if vim.tbl_contains({ 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' }, ft) then
                -- Only refresh if buffer is visible in at least one window
                local wins = vim.api.nvim_buf_get_windows(bufnr)
                if #wins > 0 then
                  if virtual_text.is_enabled(bufnr) then
                    virtual_text.refresh(bufnr)
                  end
                  if diagnostics.is_enabled(bufnr) then
                    diagnostics.refresh(bufnr)
                  end
                end
              end
            end
          end
        end)
      end
    end,
  })

  -- Also refresh diagnostics when focusing window (catch external changes)
  vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter' }, {
    group = group,
    pattern = { '*.js', '*.jsx', '*.ts', '*.tsx' },
    callback = function(args)
      local bufnr = args.buf
      local ft = vim.bo[bufnr].filetype

      if vim.tbl_contains({ 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' }, ft) then
        -- Check if translation files might have changed
        vim.schedule(function()
          if diagnostics.is_enabled(bufnr) then
            diagnostics.refresh(bufnr)
          end
          if virtual_text.is_enabled(bufnr) then
            virtual_text.refresh(bufnr)
          end
        end)
      end
    end,
  })

  initialized = true
end

--- Check if plugin is initialized
---@return boolean
function M.is_initialized()
  return initialized
end

--- Get current configuration
---@return I18nConfig
function M.get_config()
  local config = require('i18n.config')
  return config.get()
end

--- Update configuration at runtime
---@param path string Configuration path (e.g., "virtual_text.enabled")
---@param value any New value
function M.set_config(path, value)
  local config = require('i18n.config')
  config.set(path, value)
end

--- Get translation for a key
---@param key string Translation key
---@param lang? string Language code (defaults to primary language)
---@param bufnr? number Buffer number
---@return string|nil translation
function M.get_translation(key, lang, bufnr)
  local translation_source = require('i18n.translation_source')
  return translation_source.get_translation(key, lang, bufnr)
end

--- Get all translations for a key
---@param key string Translation key
---@param bufnr? number Buffer number
---@return table<string, string> translations
function M.get_all_translations(key, bufnr)
  local translation_source = require('i18n.translation_source')
  return translation_source.get_all_translations(key, bufnr)
end

--- Set translation for a key
---@param key string Translation key
---@param lang string Language code
---@param value string Translation value
---@param bufnr? number Buffer number
---@return boolean success
function M.set_translation(key, lang, value, bufnr)
  local editor = require('i18n.editor')
  return editor.set_translation(key, lang, value, bufnr)
end

--- Translate text
---@param text string Text to translate
---@param from_lang string Source language code
---@param to_lang string Target language code
---@param service? string Translation service name
---@return string|nil translated
---@return string|nil error
function M.translate_text(text, from_lang, to_lang, service)
  local translator = require('i18n.translator')
  return translator.translate_text(text, from_lang, to_lang, service)
end

--- Translate a translation key
---@param key string Translation key
---@param from_lang string Source language code
---@param to_lang string Target language code
---@param service? string Translation service name
---@param bufnr? number Buffer number
---@return boolean success
function M.translate_key(key, from_lang, to_lang, service, bufnr)
  local translator = require('i18n.translator')
  return translator.translate_key(key, from_lang, to_lang, service, bufnr)
end

--- Get translation key at cursor position
---@param bufnr? number Buffer number
---@param row? number Row number (0-indexed)
---@param col? number Column number (0-indexed)
---@return string|nil key
function M.get_key_at_position(bufnr, row, col)
  local analyzer = require('i18n.analyzer')
  return analyzer.get_key_at_position(bufnr, row, col)
end

--- Get all translation keys in buffer
---@param bufnr? number Buffer number
---@return I18nKeyLocation[] keys
function M.get_all_keys(bufnr)
  local analyzer = require('i18n.analyzer')
  return analyzer.get_all_keys(bufnr)
end

--- Enable virtual text for buffer
---@param bufnr? number Buffer number
function M.enable_virtual_text(bufnr)
  local virtual_text = require('i18n.virtual_text')
  virtual_text.enable(bufnr)
end

--- Disable virtual text for buffer
---@param bufnr? number Buffer number
function M.disable_virtual_text(bufnr)
  local virtual_text = require('i18n.virtual_text')
  virtual_text.disable(bufnr)
end

--- Toggle virtual text for buffer
---@param bufnr? number Buffer number
function M.toggle_virtual_text(bufnr)
  local virtual_text = require('i18n.virtual_text')
  virtual_text.toggle(bufnr)
end

--- Reload translation files
---@param root_dir? string Project root directory
function M.reload(root_dir)
  local translation_source = require('i18n.translation_source')
  translation_source.reload(root_dir)
end

--- Add translation from selected text with auto-translation
---@param bufnr? number Buffer number
function M.add_from_selection(bufnr)
  local editor = require('i18n.editor')
  editor.add_from_selection(bufnr)
end

--- Enable diagnostics for buffer
---@param bufnr? number Buffer number
function M.enable_diagnostics(bufnr)
  local diagnostics = require('i18n.diagnostics')
  diagnostics.enable(bufnr)
end

--- Disable diagnostics for buffer
---@param bufnr? number Buffer number
function M.disable_diagnostics(bufnr)
  local diagnostics = require('i18n.diagnostics')
  diagnostics.disable(bufnr)
end

--- Toggle diagnostics for buffer
---@param bufnr? number Buffer number
function M.toggle_diagnostics(bufnr)
  local diagnostics = require('i18n.diagnostics')
  diagnostics.toggle(bufnr)
end

return M
