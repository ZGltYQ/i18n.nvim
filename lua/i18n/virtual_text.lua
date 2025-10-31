local config = require('i18n.config')
local utils = require('i18n.utils')
local analyzer = require('i18n.analyzer')
local translation_source = require('i18n.translation_source')

local M = {}

--- Namespace for virtual text extmarks
local namespace = vim.api.nvim_create_namespace('i18n_virtual_text')

--- Cache for buffer state
---@type table<number, boolean>
local buffer_enabled = {}

--- Create virtual text for a translation key
---@param bufnr number Buffer number
---@param key_location I18nKeyLocation Key location info
local function create_virtual_text(bufnr, key_location)
  local conf = config.get()

  if not conf.virtual_text.enabled then
    return
  end

  -- Get translation
  local translation = translation_source.get_translation(key_location.key, conf.primary_language, bufnr)

  if not translation then
    translation = conf.virtual_text.fallback_text
  end

  -- Truncate if needed
  if #translation > conf.virtual_text.max_length then
    translation = utils.truncate(translation, conf.virtual_text.max_length)
  end

  -- Build virtual text
  local virt_text = conf.virtual_text.prefix .. translation .. conf.virtual_text.suffix

  -- Set extmark
  vim.api.nvim_buf_set_extmark(bufnr, namespace, key_location.row, key_location.end_col, {
    virt_text = { { virt_text, conf.virtual_text.hl_group } },
    virt_text_pos = 'eol',
    hl_mode = 'combine',
  })
end

--- Update virtual text for buffer
---@param bufnr number Buffer number
local function update_buffer(bufnr)
  if not buffer_enabled[bufnr] then
    return
  end

  if not analyzer.is_available(bufnr) then
    return
  end

  -- Clear existing extmarks
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

  -- Get all translation keys in buffer
  local keys = analyzer.get_all_keys(bufnr)

  -- Create virtual text for each key
  for _, key_location in ipairs(keys) do
    create_virtual_text(bufnr, key_location)
  end
end

--- Enable virtual text for buffer
---@param bufnr? number Buffer number (defaults to current buffer)
function M.enable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if buffer_enabled[bufnr] then
    return
  end

  buffer_enabled[bufnr] = true

  -- Set up autocommands for this buffer
  local group = vim.api.nvim_create_augroup('i18n_virtual_text_' .. bufnr, { clear = true })

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'BufEnter' }, {
    group = group,
    buffer = bufnr,
    callback = function()
      update_buffer(bufnr)
    end,
  })

  -- Clean up when buffer is deleted
  vim.api.nvim_create_autocmd('BufDelete', {
    group = group,
    buffer = bufnr,
    callback = function()
      buffer_enabled[bufnr] = nil
      vim.api.nvim_del_augroup_by_id(group)
    end,
  })

  -- Initial update
  update_buffer(bufnr)

  utils.notify('Virtual text enabled')
end

--- Disable virtual text for buffer
---@param bufnr? number Buffer number (defaults to current buffer)
function M.disable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not buffer_enabled[bufnr] then
    return
  end

  buffer_enabled[bufnr] = nil

  -- Clear virtual text
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

  -- Delete autocommands
  local ok = pcall(vim.api.nvim_del_augroup_by_name, 'i18n_virtual_text_' .. bufnr)
  if not ok then
    -- Augroup already deleted
  end

  utils.notify('Virtual text disabled')
end

--- Toggle virtual text for buffer
---@param bufnr? number Buffer number (defaults to current buffer)
function M.toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if buffer_enabled[bufnr] then
    M.disable(bufnr)
  else
    M.enable(bufnr)
  end
end

--- Check if virtual text is enabled for buffer
---@param bufnr? number Buffer number (defaults to current buffer)
---@return boolean enabled
function M.is_enabled(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return buffer_enabled[bufnr] == true
end

--- Refresh virtual text for buffer
---@param bufnr? number Buffer number (defaults to current buffer)
function M.refresh(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if buffer_enabled[bufnr] then
    update_buffer(bufnr)
  end
end

--- Set up virtual text for all open buffers
function M.setup_all()
  local conf = config.get()

  if not conf.virtual_text.enabled then
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
