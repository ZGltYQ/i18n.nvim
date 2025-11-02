local M = {}

--- Find the project root directory
---@param bufnr? number Buffer number (defaults to current buffer)
---@return string|nil root_dir Project root directory or nil if not found
function M.get_project_root(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local bufname = vim.api.nvim_buf_get_name(bufnr)

  if bufname == '' then
    return nil
  end

  -- Try to find package.json (common for i18next projects)
  local root = vim.fs.find({ 'package.json', '.git' }, {
    upward = true,
    path = vim.fs.dirname(bufname),
  })[1]

  if root then
    return vim.fs.dirname(root)
  end

  -- Fallback to current working directory
  return vim.fn.getcwd()
end

--- Check if a file or directory exists
---@param path string
---@return boolean
function M.exists(path)
  local stat = vim.loop.fs_stat(path)
  return stat ~= nil
end

--- Check if i18next is installed in the project
---@param root_dir string Project root directory
---@return boolean
function M.is_i18next_project(root_dir)
  local package_json_path = root_dir .. '/package.json'

  if not M.exists(package_json_path) then
    return false
  end

  local ok, package_json = pcall(function()
    local content = vim.fn.readfile(package_json_path)
    return vim.fn.json_decode(table.concat(content, '\n'))
  end)

  if not ok then
    return false
  end

  -- Check if i18next is in dependencies or devDependencies
  local i18next_packages = {
    'i18next',
    'react-i18next',
    'next-i18next',
  }

  for _, pkg in ipairs(i18next_packages) do
    if package_json.dependencies and package_json.dependencies[pkg] then
      return true
    end
    if package_json.devDependencies and package_json.devDependencies[pkg] then
      return true
    end
  end

  return false
end

--- Split a translation key into parts
---@param key string Translation key (e.g., "user.profile.name")
---@param separator? string Key separator (defaults to ".")
---@return string[] key_parts Array of key parts
function M.split_key(key, separator)
  separator = separator or '.'
  return vim.split(key, separator, { plain = true, trimempty = true })
end

--- Join key parts into a translation key
---@param parts string[] Key parts
---@param separator? string Key separator (defaults to ".")
---@return string key Joined translation key
function M.join_key(parts, separator)
  separator = separator or '.'
  return table.concat(parts, separator)
end

--- Get nested value from table using key path
---@param tbl table Source table
---@param key_parts string[] Key path parts
---@return any|nil value The value at the key path, or nil if not found
function M.tbl_get(tbl, key_parts)
  local current = tbl

  for _, part in ipairs(key_parts) do
    if type(current) ~= 'table' then
      return nil
    end
    current = current[part]
    if current == nil then
      return nil
    end
  end

  return current
end

--- Set nested value in table using key path
---@param tbl table Target table
---@param key_parts string[] Key path parts
---@param value any Value to set
function M.tbl_set(tbl, key_parts, value)
  local current = tbl

  for i = 1, #key_parts - 1 do
    local part = key_parts[i]
    if current[part] == nil or type(current[part]) ~= 'table' then
      current[part] = {}
    end
    current = current[part]
  end

  current[key_parts[#key_parts]] = value
end

--- Extract language from filename or parent directory
---@param filename string Filename (e.g., "en.json", "locales/es.yaml", "locales/en/translation.json")
---@return string|nil lang Language code or nil if not detected
function M.extract_language(filename)
  -- First, try to extract basename without extension (for files like "en.json")
  local basename = vim.fn.fnamemodify(filename, ':t:r')

  -- Common language codes (2-5 characters)
  if basename:match('^[a-z][a-z]$') or basename:match('^[a-z][a-z][-_][A-Z][A-Z]$') then
    return basename
  end

  -- If that didn't work, try parent directory name (for files like "locales/en/translation.json")
  local parent_dir = vim.fn.fnamemodify(filename, ':h:t')
  if parent_dir:match('^[a-z][a-z]$') or parent_dir:match('^[a-z][a-z][-_][A-Z][A-Z]$') then
    return parent_dir
  end

  return nil
end

--- Truncate text to a maximum length
---@param text string Text to truncate
---@param max_length number Maximum length
---@param suffix? string Suffix to append when truncated (defaults to "...")
---@return string truncated Truncated text
function M.truncate(text, max_length, suffix)
  suffix = suffix or '...'

  if #text <= max_length then
    return text
  end

  return text:sub(1, max_length - #suffix) .. suffix
end

--- Check if a command is available in PATH
---@param cmd string Command name
---@return boolean available True if command is available
function M.command_exists(cmd)
  return vim.fn.executable(cmd) == 1
end

--- Notify user with a message
---@param msg string Message to display
---@param level? number Log level (vim.log.levels)
function M.notify(msg, level)
  level = level or vim.log.levels.INFO
  vim.notify('[i18n.nvim] ' .. msg, level)
end

--- Escape special characters for use in Lua patterns
---@param str string String to escape
---@return string escaped Escaped string
function M.escape_pattern(str)
  return str:gsub('[%^%$%(%)%%%.%[%]%*%+%-%?]', '%%%1')
end

return M
