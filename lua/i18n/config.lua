local M = {}

---@class I18nConfig
---@field primary_language string
---@field translation_source string[]
---@field key_separator string
---@field scan_depth number Maximum directory depth for translation file scanning
---@field virtual_text I18nVirtualTextConfig
---@field diagnostic I18nDiagnosticConfig
---@field translator I18nTranslatorConfig
---@field i18next I18nI18nextConfig

---@class I18nVirtualTextConfig
---@field enabled boolean
---@field max_length number
---@field prefix string
---@field suffix string
---@field hl_group string
---@field fallback_text string

---@class I18nDiagnosticConfig
---@field enabled boolean
---@field severity number

---@class I18nTranslatorConfig
---@field default string
---@field services table<string, I18nTranslatorServiceConfig>

---@class I18nTranslatorServiceConfig
---@field type? string
---@field api_key? string

---@class I18nI18nextConfig
---@field plural_suffixes string[]

---@type I18nConfig
M.defaults = {
  primary_language = 'en',

  translation_source = {
    '**/locales/**/*.{json,yml,yaml}',
    '**/translations/**/*.{json,yml,yaml}',
    '**/i18n/**/*.{json,yml,yaml}',
    '**/lang/**/*.{json,yml,yaml}',
  },

  key_separator = '.',

  -- Maximum directory depth for scanning translation files
  -- Lower values improve performance in large projects
  scan_depth = 5,

  virtual_text = {
    enabled = true,
    max_length = 80,
    prefix = '<: ',
    suffix = '>',
    hl_group = 'Comment',
    fallback_text = '[Missing]',
  },

  diagnostic = {
    enabled = true,
    severity = vim.diagnostic.severity.WARN,
  },

  translator = {
    default = 'google',
    services = {
      google = {
        type = 'free',
        api_key = nil,
      },
      deepl = {
        api_key = nil,
      },
    },
  },

  i18next = {
    plural_suffixes = {
      '_zero',
      '_one',
      '_two',
      '_few',
      '_many',
      '_other',
      '_ordinal_zero',
      '_ordinal_one',
      '_ordinal_two',
      '_ordinal_few',
      '_ordinal_many',
      '_ordinal_other',
    },
  },
}

---@type I18nConfig
M.config = vim.deepcopy(M.defaults)

--- Setup configuration
---@param opts? I18nConfig
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.defaults, opts or {})
end

--- Get current configuration
---@return I18nConfig
function M.get()
  return M.config
end

--- Update configuration at runtime
---@param path string Dot-separated path (e.g., "virtual_text.enabled")
---@param value any
function M.set(path, value)
  local keys = vim.split(path, '.', { plain = true })
  local current = M.config

  for i = 1, #keys - 1 do
    if current[keys[i]] == nil then
      current[keys[i]] = {}
    end
    current = current[keys[i]]
  end

  current[keys[#keys]] = value
end

return M
