local config = require('i18n.config')
local utils = require('i18n.utils')
local Path = require('plenary.path')
local scandir = require('plenary.scandir')

local M = {}

---@class TranslationFile
---@field path string Absolute path to the translation file
---@field language string Language code
---@field content table Parsed translation content

---@class TranslationSource
---@field root_dir string Project root directory
---@field files table<string, TranslationFile> Map of language to translation file

--- Cache for translation sources per project
---@type table<string, TranslationSource>
local cache = {}

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

    -- Use scandir to find files
    local found = scandir.scan_dir(root_dir, {
      respect_gitignore = true,
      search_pattern = function(entry)
        return entry:match('%.json$') or entry:match('%.ya?ml$')
      end,
      depth = 10,
    })

    for _, file_path in ipairs(found) do
      -- Check if file matches the pattern
      local relative = file_path:sub(#root_dir + 2)

      for _, check_pattern in ipairs(conf.translation_source) do
        -- Convert glob to Lua pattern
        local lua_pattern = check_pattern
          :gsub('%.', '%%.')
          :gsub('%*%*/', '.-/')
          :gsub('%*', '[^/]*')
          :gsub('%.%{json,yml,yaml%}', '%%.%%w+')

        if relative:match(lua_pattern) then
          local lang = utils.extract_language(file_path)

          if lang then
            local content = parse_file(file_path)

            if content then
              files[lang] = {
                path = file_path,
                language = lang,
                content = content,
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

--- Reload translation source from disk
---@param root_dir? string Project root directory (defaults to current buffer's project)
function M.reload(root_dir)
  if not root_dir then
    root_dir = utils.get_project_root()
  end

  if not root_dir then
    return
  end

  -- Clear cache
  cache[root_dir] = nil

  -- Reload
  M.get_source()
  utils.notify('Translation files reloaded')
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

  -- Split key into parts
  local key_parts = utils.split_key(key, conf.key_separator)

  -- Try to get the translation
  local translation = utils.tbl_get(file.content, key_parts)

  if translation then
    return translation
  end

  -- Try plural suffixes for i18next
  for _, suffix in ipairs(conf.i18next.plural_suffixes) do
    local plural_key_parts = vim.list_extend({}, key_parts)
    plural_key_parts[#plural_key_parts] = plural_key_parts[#plural_key_parts] .. suffix

    translation = utils.tbl_get(file.content, plural_key_parts)
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
