local config = require('i18n.config')
local utils = require('i18n.utils')
local Path = require('plenary.path')
local scandir = require('plenary.scandir')

local M = {}

---@class TranslationFile
---@field path string Absolute path to the translation file
---@field language string Language code
---@field content table Parsed translation content
---@field mtime number File modification time (seconds since epoch)
---@field flat_index table<string, string> Flattened key index for O(1) lookups

---@class TranslationSource
---@field root_dir string Project root directory
---@field files table<string, TranslationFile> Map of language to translation file

--- Cache for translation sources per project
---@type table<string, TranslationSource>
local cache = {}

--- Get file modification time
---@param file_path string
---@return number|nil mtime Modification time in seconds or nil on error
local function get_file_mtime(file_path)
  local stat = vim.loop.fs_stat(file_path)
  return stat and stat.mtime.sec or nil
end

--- Build flattened index from nested translation content
---@param content table Nested translation content
---@param separator string Key separator
---@return table<string, string> flat_index Map of flattened keys to values
local function build_flat_index(content, separator)
  local flat = {}

  ---@param tbl table
  ---@param prefix string
  local function flatten(tbl, prefix)
    for key, value in pairs(tbl) do
      local full_key = prefix == '' and key or (prefix .. separator .. key)

      if type(value) == 'table' then
        flatten(value, full_key)
      elseif type(value) == 'string' then
        flat[full_key] = value
      end
    end
  end

  flatten(content, '')
  return flat
end

--- Parse JSON file
---@param file_path string
---@return table|nil content Parsed content or nil on error
local function parse_json(file_path)
  local ok, content = pcall(function()
    local lines = vim.fn.readfile(file_path)
    return vim.fn.json_decode(table.concat(lines, '\n'))
  end)

  if not ok then
    utils.notify('Failed to parse JSON file: ' .. file_path, vim.log.levels.WARN)
    return nil
  end

  return content
end

--- Parse YAML file
---@param file_path string
---@return table|nil content Parsed content or nil on error
local function parse_yaml(file_path)
  -- Check if yq is available
  if not utils.command_exists('yq') then
    utils.notify('yq command not found. Install yq to support YAML files.', vim.log.levels.WARN)
    return nil
  end

  local result = vim.fn.system({ 'yq', 'eval', '-o=json', file_path })

  if vim.v.shell_error ~= 0 then
    utils.notify('Failed to parse YAML file: ' .. file_path, vim.log.levels.WARN)
    return nil
  end

  local ok, content = pcall(vim.fn.json_decode, result)
  if not ok then
    return nil
  end

  return content
end

--- Parse translation file based on extension
---@param file_path string
---@return table|nil content Parsed content or nil on error
local function parse_file(file_path)
  local ext = vim.fn.fnamemodify(file_path, ':e')

  if ext == 'json' then
    return parse_json(file_path)
  elseif ext == 'yml' or ext == 'yaml' then
    return parse_yaml(file_path)
  end

  return nil
end

--- Find all translation files in the project
---@param root_dir string Project root directory
---@return table<string, TranslationFile> files Map of language to translation file
local function find_translation_files(root_dir)
  local conf = config.get()
  local files = {}

  for _, pattern in ipairs(conf.translation_source) do
    -- Convert glob pattern to find pattern
    local find_pattern = pattern:gsub('%*%*/', ''):gsub('%.%{[^}]+%}', '.*')

    -- Use scandir to find files with configurable depth limit
    local found = scandir.scan_dir(root_dir, {
      respect_gitignore = true,
      search_pattern = function(entry)
        return entry:match('%.json$') or entry:match('%.ya?ml$')
      end,
      depth = conf.scan_depth,
    })

    for _, file_path in ipairs(found) do
      -- Check if file matches the pattern
      local relative = file_path:sub(#root_dir + 2)

      for _, check_pattern in ipairs(conf.translation_source) do
        -- Convert glob to Lua pattern
        -- Handle file extension glob: .{json,yml,yaml} → any word extension
        local lua_pattern = check_pattern
          :gsub('%.%{[^}]+%}', '__EXT__')   -- Placeholder for extension glob
          :gsub('%.', '%%.')                 -- Escape remaining literal dots
          :gsub('__EXT__', '%%.[^/]+$')      -- Extension: dot + any non-slash chars at end
          :gsub('%*%*/', '.-/')              -- ** → any path
          :gsub('%*', '[^/]*')               -- * → any filename chars

        if relative:match(lua_pattern) then
          local lang = utils.extract_language(file_path)

          if lang then
            local content = parse_file(file_path)
            local mtime = get_file_mtime(file_path)

            if content and mtime then
              -- Build flattened index for fast lookups
              local flat_index = build_flat_index(content, conf.key_separator)

              files[lang] = {
                path = file_path,
                language = lang,
                content = content,
                mtime = mtime,
                flat_index = flat_index,
              }
            end
          end
          break
        end
      end
    end
  end

  return files
end

--- Get or create translation source for a project
---@param bufnr? number Buffer number (defaults to current buffer)
---@return TranslationSource|nil source Translation source or nil if not found
function M.get_source(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local root_dir = utils.get_project_root(bufnr)

  if not root_dir then
    return nil
  end

  -- Check cache
  if cache[root_dir] then
    return cache[root_dir]
  end

  -- Find translation files
  local files = find_translation_files(root_dir)

  if vim.tbl_isempty(files) then
    return nil
  end

  -- Create and cache source
  local source = {
    root_dir = root_dir,
    files = files,
  }

  cache[root_dir] = source
  return source
end

--- Reload translation source from disk (incrementally checks mtimes)
---@param root_dir? string Project root directory (defaults to current buffer's project)
function M.reload(root_dir)
  if not root_dir then
    root_dir = utils.get_project_root()
  end

  if not root_dir then
    return
  end

  -- Get existing cache if available
  local existing = cache[root_dir]

  if not existing then
    -- No cache exists, do full reload
    local files = find_translation_files(root_dir)

    if not vim.tbl_isempty(files) then
      cache[root_dir] = {
        root_dir = root_dir,
        files = files,
      }
      utils.notify('Translation files loaded')
    else
      utils.notify('No translation files found', vim.log.levels.WARN)
    end
    return
  end

  -- Incremental reload: check mtimes and only reparse changed files
  local files_changed = 0
  local files_removed = 0
  local files_added = 0

  -- Scan for all current translation files
  local current_files = find_translation_files(root_dir)

  -- Build map of file paths from existing cache
  local existing_paths = {}
  for _, file in pairs(existing.files) do
    existing_paths[file.path] = file.language
  end

  -- Check for removed files
  for lang, file in pairs(existing.files) do
    if not current_files[lang] then
      existing.files[lang] = nil
      files_removed = files_removed + 1
    end
  end

  -- Check for new and modified files
  for lang, new_file in pairs(current_files) do
    local existing_file = existing.files[lang]

    if not existing_file then
      -- New file
      existing.files[lang] = new_file
      files_added = files_added + 1
    elseif existing_file.mtime ~= new_file.mtime then
      -- File modified - update it
      existing.files[lang] = new_file
      files_changed = files_changed + 1
    end
    -- else: file unchanged, keep cached version
  end

  -- Notify about changes
  if files_added > 0 or files_changed > 0 or files_removed > 0 then
    local msg = string.format(
      'Translation files updated: +%d ±%d -%d',
      files_added,
      files_changed,
      files_removed
    )
    utils.notify(msg)
  else
    utils.notify('No translation file changes detected')
  end
end

--- Get translation for a key
---@param key string Translation key
---@param lang? string Language code (defaults to primary language)
---@param bufnr? number Buffer number
---@return string|nil translation Translation text or nil if not found
function M.get_translation(key, lang, bufnr)
  local conf = config.get()
  lang = lang or conf.primary_language

  local source = M.get_source(bufnr)
  if not source then
    return nil
  end

  local file = source.files[lang]
  if not file then
    return nil
  end

  -- Use flat index for O(1) lookup
  local translation = file.flat_index[key]

  if translation then
    return translation
  end

  -- Try plural suffixes for i18next
  for _, suffix in ipairs(conf.i18next.plural_suffixes) do
    local plural_key = key .. suffix
    translation = file.flat_index[plural_key]

    if translation then
      return translation
    end
  end

  return nil
end

--- Get all translations for a key across languages
---@param key string Translation key
---@param bufnr? number Buffer number
---@return table<string, string> translations Map of language to translation
function M.get_all_translations(key, bufnr)
  local source = M.get_source(bufnr)
  if not source then
    return {}
  end

  local translations = {}

  for lang, file in pairs(source.files) do
    local translation = M.get_translation(key, lang, bufnr)
    if translation then
      translations[lang] = translation
    end
  end

  return translations
end

--- Check if a key exists in any translation file
---@param key string Translation key
---@param bufnr? number Buffer number
---@return boolean exists True if key exists
function M.key_exists(key, bufnr)
  local translations = M.get_all_translations(key, bufnr)
  return not vim.tbl_isempty(translations)
end

--- Get all languages in the project
---@param bufnr? number Buffer number
---@return string[] languages Array of language codes
function M.get_languages(bufnr)
  local source = M.get_source(bufnr)
  if not source then
    return {}
  end

  return vim.tbl_keys(source.files)
end

--- Get missing translations for a key
---@param key string Translation key
---@param bufnr? number Buffer number
---@return string[] languages Array of language codes where translation is missing
function M.get_missing_languages(key, bufnr)
  local source = M.get_source(bufnr)
  if not source then
    return {}
  end

  local missing = {}

  for lang, _ in pairs(source.files) do
    if not M.get_translation(key, lang, bufnr) then
      table.insert(missing, lang)
    end
  end

  return missing
end

--- Clear cache (useful for testing)
function M.clear_cache()
  cache = {}
end

return M
