--- i18n.nvim plugin loader
--- This file is automatically sourced by Neovim

-- Prevent loading the plugin twice
if vim.g.loaded_i18n then
  return
end
vim.g.loaded_i18n = 1

-- Check Neovim version
if vim.fn.has('nvim-0.10.0') == 0 then
  vim.notify('[i18n.nvim] Requires Neovim >= 0.10.0', vim.log.levels.ERROR)
  return
end

-- The plugin will be loaded when setup() is called by the user
