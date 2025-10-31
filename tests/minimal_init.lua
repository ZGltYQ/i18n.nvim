--- Minimal init file for running tests with plenary.nvim

-- Add plugin to runtime path
vim.opt.rtp:append('.')

-- Add plenary to runtime path (adjust path as needed)
local plenary_path = vim.fn.stdpath('data') .. '/lazy/plenary.nvim'
if vim.fn.isdirectory(plenary_path) == 1 then
  vim.opt.rtp:append(plenary_path)
end

-- Load plugin
require('i18n').setup({
  virtual_text = {
    enabled = false, -- Disable for tests
  },
})

-- Print loaded message
print('Test environment initialized')
