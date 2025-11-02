local utils = require('i18n.utils')

local M = {}

--- Get the directory containing query files
---@return string query_dir
local function get_query_dir()
  local source = debug.getinfo(1, 'S').source:sub(2)
  local plugin_root = vim.fn.fnamemodify(source, ':p:h:h:h')
  return plugin_root .. '/queries'
end

--- Load Treesitter query from file
---@param query_file string Query file path
---@param lang string Language to parse query for
---@return vim.treesitter.Query|nil query
local function load_query(query_file, lang)
  if not utils.exists(query_file) then
    return nil
  end

  local content = table.concat(vim.fn.readfile(query_file), '\n')

  local ok, query = pcall(vim.treesitter.query.parse, lang, content)
  if not ok then
    utils.notify('Failed to parse query: ' .. query_file, vim.log.levels.WARN)
    return nil
  end

  return query
end

--- Get all Treesitter queries for i18next
---@param lang string Language for query parsing
---@return vim.treesitter.Query[] queries
local function get_queries(lang)
  -- Map language to appropriate parser language for queries
  -- JSX/TSX files need the tsx parser for JSX node types
  local query_lang = lang
  local is_jsx = false

  if lang == 'javascriptreact' or lang == 'typescriptreact' then
    query_lang = 'tsx'
    is_jsx = true
  elseif lang == 'javascript' or lang == 'typescript' then
    query_lang = 'typescript'
    is_jsx = false
  end

  local query_dir = get_query_dir()
  local queries = {}

  -- Always load i18next.scm (works with all JS/TS files)
  local i18next_query = load_query(query_dir .. '/i18next.scm', query_lang)
  if i18next_query then
    table.insert(queries, i18next_query)
  end

  -- Only load react-i18next.scm for JSX/TSX files
  if is_jsx then
    local react_query = load_query(query_dir .. '/react-i18next.scm', query_lang)
    if react_query then
      table.insert(queries, react_query)
    end
  end

  return queries
end

--- Get Treesitter parser for buffer
---@param bufnr number Buffer number
---@return vim.treesitter.LanguageTree|nil parser
local function get_parser(bufnr)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok then
    return nil
  end

  local lang = parser:lang()

  -- Check if language is supported (JavaScript, TypeScript, JSX, TSX)
  if not vim.tbl_contains({ 'javascript', 'typescript', 'javascriptreact', 'typescriptreact' }, lang) then
    return nil
  end

  return parser
end

--- Extract translation key from capture node
---@param node TSNode
---@return string|nil key
local function extract_key_from_node(node)
  local text = vim.treesitter.get_node_text(node, 0)

  if not text then
    return nil
  end

  -- Remove quotes from string
  text = text:gsub('^["\']', ''):gsub('["\']$', '')

  return text
end

--- Get translation key at cursor position
---@param bufnr? number Buffer number (defaults to current buffer)
---@param row? number Row number (0-indexed, defaults to cursor row)
---@param col? number Column number (0-indexed, defaults to cursor col)
---@return string|nil key Translation key or nil if not found
function M.get_key_at_position(bufnr, row, col)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Get cursor position if not provided
  if not row or not col then
    local cursor = vim.api.nvim_win_get_cursor(0)
    row = cursor[1] - 1 -- Convert to 0-indexed
    col = cursor[2]
  end

  local parser = get_parser(bufnr)
  if not parser then
    return nil
  end

  local lang = parser:lang()

  local tree = parser:parse()[1]
  if not tree then
    return nil
  end

  local queries = get_queries(lang)
  if #queries == 0 then
    utils.notify('No Treesitter queries loaded', vim.log.levels.WARN)
    return nil
  end

  -- Find the smallest node at cursor position
  local root = tree:root()
  local node = root:descendant_for_range(row, col, row, col)

  if not node then
    return nil
  end

  -- Try each query to find a match
  for _, query in ipairs(queries) do
    for id, match_node, metadata in query:iter_captures(root, bufnr) do
      local capture_name = query.captures[id]

      if capture_name == 'i18n.key' then
        -- Check if this node contains or is contained by our cursor node
        local match_start_row, match_start_col, match_end_row, match_end_col = match_node:range()

        if match_start_row <= row and row <= match_end_row then
          if match_start_row == row and match_start_col > col then
            goto continue
          end
          if match_end_row == row and match_end_col < col then
            goto continue
          end

          local key = extract_key_from_node(match_node)
          if key then
            return key
          end
        end
      end

      ::continue::
    end
  end

  return nil
end

---@class I18nKeyLocation
---@field key string Translation key
---@field row number Row number (0-indexed)
---@field col number Column number (0-indexed)
---@field end_row number End row number (0-indexed)
---@field end_col number End column number (0-indexed)

--- Get all translation keys in buffer
---@param bufnr? number Buffer number (defaults to current buffer)
---@return I18nKeyLocation[] keys Array of translation key locations
function M.get_all_keys(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local parser = get_parser(bufnr)
  if not parser then
    return {}
  end

  local lang = parser:lang()

  local tree = parser:parse()[1]
  if not tree then
    return {}
  end

  local queries = get_queries(lang)
  if #queries == 0 then
    return {}
  end

  local keys = {}
  local root = tree:root()

  for _, query in ipairs(queries) do
    for id, node, metadata in query:iter_captures(root, bufnr) do
      local capture_name = query.captures[id]

      if capture_name == 'i18n.key' then
        local key = extract_key_from_node(node)

        if key then
          local start_row, start_col, end_row, end_col = node:range()

          table.insert(keys, {
            key = key,
            row = start_row,
            col = start_col,
            end_row = end_row,
            end_col = end_col,
          })
        end
      end
    end
  end

  return keys
end

--- Check if Treesitter is available for current buffer
---@param bufnr? number Buffer number (defaults to current buffer)
---@return boolean available
function M.is_available(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return get_parser(bufnr) ~= nil
end

return M
