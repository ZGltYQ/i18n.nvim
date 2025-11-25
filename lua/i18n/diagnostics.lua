local config = require('i18n.config')
local utils = require('i18n.utils')
local analyzer = require('i18n.analyzer')
local translation_source = require('i18n.translation_source')
local debounce = require('i18n.debounce')

local M = {}

--- Namespace for diagnostics
local namespace = vim.api.nvim_create_namespace('i18n_diagnostics')

--- Cache for buffer state
---@type table<number, boolean>
local buffer_enabled = {}

--- Cache for debounced update functions per buffer
---@type table<number, {fn: function, timer: userdata}>
local buffer_debounced = {}

--- Create diagnostic for a translation key with missing translations
---@param bufnr number Buffer number
---@param key_location I18nKeyLocation Key location info
---@return vim.Diagnostic|nil diagnostic
local function create_diagnostic(bufnr, key_location)
  local conf = config.get()

  if not conf.diagnostic.enabled then
    return nil
  end

  -- Get missing languages for this key
  local missing_langs = translation_source.get_missing_languages(key_location.key, bufnr)

  -- Only create diagnostic if there are missing translations
  if #missing_langs == 0 then
    return nil
  end

  -- Build diagnostic message
  local message = string.format(
    'Translation key "%s" is missing in: %s',
    key_location.key,
    table.concat(missing_langs, ', ')
  )

  return {
    lnum = key_location.row,
    col = key_location.col,
    end_lnum = key_location.end_row,
    end_col = key_location.end_col,
    severity = conf.diagnostic.severity,
    message = message,
    source = 'i18n',
  }
end

--- Update diagnostics for buffer
---@param bufnr number Buffer number
local function update_buffer(bufnr)
  -- Check if buffer is still valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  if not buffer_enabled[bufnr] then
    return
  end

  if not analyzer.is_available(bufnr) then
    return
  end

  local conf = config.get()

  if not conf.diagnostic.enabled then
    -- Clear diagnostics if disabled
    vim.diagnostic.set(namespace, bufnr, {})
    return
  end

  -- Get all translation keys in buffer
  local ok, keys = pcall(analyzer.get_all_keys, bufnr)

  if not ok then
    -- Clear diagnostics on error to prevent stale data
    vim.diagnostic.set(namespace, bufnr, {})
    return
  end

  -- Create diagnostics for keys with missing translations
  local diagnostics = {}
  for _, key_location in ipairs(keys) do
    local diagnostic = create_diagnostic(bufnr, key_location)
    if diagnostic then
      table.insert(diagnostics, diagnostic)
    end
  end

  -- Publish diagnostics
  vim.diagnostic.set(namespace, bufnr, diagnostics)
end

--- Enable diagnostics for buffer
---@param bufnr? number Buffer number (defaults to current buffer)
function M.enable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Check if buffer is valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  if buffer_enabled[bufnr] then
    return
  end

  buffer_enabled[bufnr] = true

  -- Create debounced update function for this buffer (500ms delay)
  local debounced_fn, timer = debounce.debounce_trailing(function()
    update_buffer(bufnr)
  end, 500)

  buffer_debounced[bufnr] = { fn = debounced_fn, timer = timer }

  -- Set up autocommands for this buffer
  local group = vim.api.nvim_create_augroup('i18n_diagnostics_' .. bufnr, { clear = true })

  -- Use debounced function for text changes to prevent excessive re-parsing
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = group,
    buffer = bufnr,
    callback = function()
      debounced_fn()
    end,
  })

  -- Use immediate update for BufEnter and BufWritePost (no debounce needed)
  vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost' }, {
    group = group,
    buffer = bufnr,
    callback = function()
      update_buffer(bufnr)
    end,
  })

  -- Clean up when buffer is deleted or wiped
  vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
    group = group,
    buffer = bufnr,
    callback = function()
      buffer_enabled[bufnr] = nil
      -- Clean up debounce timer
      if buffer_debounced[bufnr] then
        buffer_debounced[bufnr].timer:close()
        buffer_debounced[bufnr] = nil
      end
      pcall(vim.diagnostic.set, namespace, bufnr, {})
      pcall(vim.api.nvim_del_augroup_by_id, group)
    end,
  })

  -- Initial update
  update_buffer(bufnr)

  utils.notify('Diagnostics enabled')
end

--- Disable diagnostics for buffer
---@param bufnr? number Buffer number (defaults to current buffer)
function M.disable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not buffer_enabled[bufnr] then
    return
  end

  buffer_enabled[bufnr] = nil

  -- Clean up debounce timer
  if buffer_debounced[bufnr] then
    buffer_debounced[bufnr].timer:close()
    buffer_debounced[bufnr] = nil
  end

  -- Clear diagnostics
  vim.diagnostic.set(namespace, bufnr, {})

  -- Delete autocommands
  local ok = pcall(vim.api.nvim_del_augroup_by_name, 'i18n_diagnostics_' .. bufnr)
  if not ok then
    -- Augroup already deleted
  end

  utils.notify('Diagnostics disabled')
end

--- Toggle diagnostics for buffer
---@param bufnr? number Buffer number (defaults to current buffer)
function M.toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if buffer_enabled[bufnr] then
    M.disable(bufnr)
  else
    M.enable(bufnr)
  end
end

--- Check if diagnostics are enabled for buffer
---@param bufnr? number Buffer number (defaults to current buffer)
---@return boolean enabled
function M.is_enabled(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return buffer_enabled[bufnr] == true
end

--- Refresh diagnostics for buffer
---@param bufnr? number Buffer number (defaults to current buffer)
function M.refresh(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if buffer_enabled[bufnr] then
    update_buffer(bufnr)
  end
end

--- Set up diagnostics for all open buffers
function M.setup_all()
  local conf = config.get()

  if not conf.diagnostic.enabled then
    return
  end

  -- Enable for all JavaScript/TypeScript buffers
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local ft = vim.bo[bufnr].filetype

      if vim.tbl_contains({ 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' }, ft) then
        M.enable(bufnr)
      end
    end
  end
end

return M
