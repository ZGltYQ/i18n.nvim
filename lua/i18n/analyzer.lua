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
  -- Determine if this is a JSX/TSX file and which query files to load
  -- IMPORTANT: Use the same language name for query parsing as the buffer's parser
  local is_jsx = lang == 'javascriptreact' or lang == 'typescriptreact'

  local query_dir = get_query_dir()
  local queries = {}

  -- Always load i18next.scm (works with all JS/TS files)
  local i18next_query = load_query(query_dir .. '/i18next.scm', lang)
  if i18next_query then
    table.insert(queries, i18next_query)
  end

  -- Only load react-i18next.scm for JSX/TSX files
  if is_jsx then
    local react_query = load_query(query_dir .. '/react-i18next.scm', lang)
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

--- Unescape JavaScript string escape sequences
---@param str string String with escape sequences
---@return string unescaped Unescaped string
local function unescape_js_string(str)
  -- Handle common JavaScript escape sequences
  local result = str
    :gsub('\\\\', '\x00')  -- Temporarily replace \\ with null byte
    :gsub('\\"', '"')      -- \" -> "
    :gsub("\\'", "'")      -- \' -> '
    :gsub('\\n', '\n')     -- \n -> newline
    :gsub('\\t', '\t')     -- \t -> tab
    :gsub('\\r', '\r')     -- \r -> carriage return
    :gsub('\\b', '\b')     -- \b -> backspace
    :gsub('\\f', '\f')     -- \f -> form feed
    :gsub('\x00', '\\')    -- Restore backslash

  return result
end

--- Extract translation key from capture node
---@param node TSNode
---@param bufnr number Buffer number
---@return string|nil key
local function extract_key_from_node(node, bufnr)
  -- Safely get node text with bounds checking
  local ok, text = pcall(vim.treesitter.get_node_text, node, bufnr)

  if not ok or not text then
    return nil
  end

  -- Remove quotes from string (in case they're included)
  text = text:gsub('^["\']', ''):gsub('["\']$', '')

  -- Note: Tree-sitter's get_node_text on string_fragment nodes returns the
  -- raw source text, which may contain escape sequences like \n, \t, etc.
  -- We need to unescape these to get the actual translation key.
  -- However, we only unescape if the text actually contains backslashes
  -- to avoid unnecessary processing.
  if text:find('\\', 1, true) then
    text = unescape_js_string(text)
  end

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
        -- Check if this node contains the cursor position
        -- Note: Tree-sitter ranges are [start, end) where end is exclusive
        local ok, match_start_row, match_start_col, match_end_row, match_end_col = pcall(match_node.range, match_node)

        if ok then
          -- Check if cursor is within the node's range [start, end)
          local in_row_range = match_start_row <= row and row <= match_end_row
          local before_start = match_start_row == row and col < match_start_col
          local after_end = match_end_row == row and col >= match_end_col

          if in_row_range and not before_start and not after_end then
            local key = extract_key_from_node(match_node, bufnr)
            if key then
              return key
            end
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
        local key = extract_key_from_node(node, bufnr)

        if key then
          -- Safely get node range with bounds checking
          local ok, start_row, start_col, end_row, end_col = pcall(node.range, node)

          if ok then
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
