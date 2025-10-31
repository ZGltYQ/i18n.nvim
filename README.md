# i18n.nvim

A comprehensive Neovim plugin for working with i18next translations. Display translations inline, edit them effortlessly, and automatically translate missing keys using multiple translation services.

## 🎥 Quick Demo

**Select text → Press hotkey → Auto-translate to all languages!**

```
1. In your code, select text: "Welcome to our application"
2. Press <leader>ta (or :I18nAddFromSelection)
3. Enter translation key: "app.welcome"
4. ✨ Magic happens:
   ├─ en.json: "Welcome to our application" (original)
   ├─ es.json: "Bienvenido a nuestra aplicación" (auto-translated)
   ├─ fr.json: "Bienvenue dans notre application" (auto-translated)
   ├─ de.json: "Willkommen in unserer Anwendung" (auto-translated)
   └─ ... all other language files updated!
```

No more copying text to Google Translate manually! 🎉

## Features

- **Inline Translation Display**: See translations directly in your code using virtual text
- **Smart Key Detection**: Treesitter-based parsing for accurate key detection
- **Quick Add from Selection**: Select text, press a hotkey, and instantly add translations to all languages! 🚀
- **Translation Editing**: Add or update translations across all language files
- **Auto-Translation**: Automatically translate missing keys using Google Translate, DeepL, or other services
- **Multiple File Formats**: Supports both JSON and YAML translation files
- **i18next Support**: Full support for i18next, react-i18next, and next-i18next
- **Diagnostics**: Warnings for missing translation keys

## Requirements

- Neovim 0.10.0+
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- Optional: `jq` (for robust JSON editing)
- Optional: `yq` (for YAML editing)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'your-username/i18n.nvim',
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
    'nvim-lua/plenary.nvim',
  },
  config = function()
    require('i18n').setup({
      -- your configuration here
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'your-username/i18n.nvim',
  requires = {
    'nvim-treesitter/nvim-treesitter',
    'nvim-lua/plenary.nvim',
  },
  config = function()
    require('i18n').setup()
  end
}
```

## Configuration

Default configuration:

```lua
require('i18n').setup({
  -- Primary language to display in virtual text
  primary_language = 'en',

  -- Pattern to find translation files (supports glob patterns)
  translation_source = {
    -- Common patterns for i18next projects
    '**/locales/**/*.{json,yml,yaml}',
    '**/translations/**/*.{json,yml,yaml}',
    '**/i18n/**/*.{json,yml,yaml}',
  },

  -- Key separator for nested translations (e.g., "user.name.first")
  key_separator = '.',

  -- Virtual text configuration
  virtual_text = {
    enabled = true,
    max_length = 80,      -- Maximum length of displayed text
    prefix = ' → ',       -- Prefix before translation
    suffix = '',          -- Suffix after translation
    hl_group = 'Comment', -- Highlight group
    fallback_text = '[Missing]', -- Text to show when translation is missing
  },

  -- Diagnostic configuration
  diagnostic = {
    enabled = true,
    severity = vim.diagnostic.severity.WARN,
  },

  -- Auto-translation configuration
  translator = {
    default = 'google',   -- Default translation service
    services = {
      google = {
        type = 'free',    -- 'free' or 'api'
        api_key = nil,    -- Required if type = 'api'
      },
      deepl = {
        api_key = nil,    -- DeepL API key
      },
    },
  },

  -- i18next specific configuration
  i18next = {
    -- Plural suffixes to check when looking for translations
    plural_suffixes = {
      '_zero', '_one', '_two', '_few', '_many', '_other',
      '_ordinal_zero', '_ordinal_one', '_ordinal_two', '_ordinal_few', '_ordinal_many', '_ordinal_other',
    },
  },
})
```

## Commands

- `:I18nSetLang [lang]` - Set the primary language for virtual text display
- `:I18nEdit [lang]` - Edit the translation at cursor position for specified language
- `:I18nAddFromSelection` - **NEW!** Select text, run this command, enter a key, and auto-translate to all languages
- `:I18nTranslate [service]` - Auto-translate missing keys in current file
- `:I18nTranslateAll [service]` - Auto-translate all missing keys in project
- `:I18nTranslateKey [key] [from] [to]` - Translate a specific key
- `:I18nVirtualTextEnable` - Enable virtual text display
- `:I18nVirtualTextDisable` - Disable virtual text display
- `:I18nVirtualTextToggle` - Toggle virtual text display
- `:I18nReload` - Reload translation files from disk
- `:I18nCopyKey` - Copy the translation key at cursor to clipboard
- `:I18nInfo` - Show all translations for key at cursor in a popup

## Usage Examples

### Basic Usage

1. Place cursor on a translation key (e.g., `t('user.welcome')`)
2. See the translation appear inline as virtual text
3. Use `:I18nEdit` to open an input dialog and edit the translation

### Quick Add Translation from Selection (NEW!)

The fastest way to add translations:

1. Select any text in visual mode (e.g., "Welcome to our app")
2. Press your keymap (e.g., `<leader>ta`) or run `:I18nAddFromSelection`
3. Enter a translation key (e.g., `app.welcome`)
4. The plugin will:
   - Add the selected text as the primary language translation
   - Automatically translate it to all other configured languages
   - Save to all translation JSON/YAML files
   - Show a summary of successful translations

Example workflow:
```vim
" 1. Visual select: "Welcome to our app"
" 2. Press <leader>ta
" 3. Enter key: app.welcome
" 4. Done! Translations added to en.json, es.json, fr.json, etc.
```

### Auto-Translation

```vim
" Translate all missing keys in the current file using Google Translate
:I18nTranslate google

" Translate all missing keys in the entire project using DeepL
:I18nTranslateAll deepl

" Translate a specific key from English to Spanish
:I18nTranslateKey user.welcome en es
```

### Keymaps (Optional)

Add these to your configuration:

```lua
-- Essential keymaps
vim.keymap.set('v', '<leader>ta', '<cmd>I18nAddFromSelection<cr>', { desc = 'Add translation from selection' })
vim.keymap.set('n', '<leader>te', '<cmd>I18nEdit<cr>', { desc = 'Edit translation' })
vim.keymap.set('n', '<leader>ti', '<cmd>I18nInfo<cr>', { desc = 'Show translation info' })

-- Translation automation
vim.keymap.set('n', '<leader>tt', '<cmd>I18nTranslate<cr>', { desc = 'Translate missing keys' })
vim.keymap.set('n', '<leader>tT', '<cmd>I18nTranslateAll<cr>', { desc = 'Translate all missing keys' })

-- Virtual text control
vim.keymap.set('n', '<leader>tv', '<cmd>I18nVirtualTextToggle<cr>', { desc = 'Toggle virtual text' })

-- Utilities
vim.keymap.set('n', '<leader>tc', '<cmd>I18nCopyKey<cr>', { desc = 'Copy translation key' })
vim.keymap.set('n', '<leader>tr', '<cmd>I18nReload<cr>', { desc = 'Reload translations' })
```

## Translation Services

### Google Translate

**Free Version** (no API key required):
```lua
translator = {
  services = {
    google = { type = 'free' }
  }
}
```

**Official API** (requires Google Cloud account):
```lua
translator = {
  services = {
    google = {
      type = 'api',
      api_key = 'your-google-cloud-api-key'
    }
  }
}
```

### DeepL

Requires a DeepL API key ([get one here](https://www.deepl.com/pro-api)):
```lua
translator = {
  services = {
    deepl = {
      api_key = 'your-deepl-api-key'
    }
  }
}
```

## Supported Patterns

The plugin detects these i18next patterns:

- `t('key')` - Standard translation function
- `i18n.t('key')` - i18next instance
- `i18next.t('key')` - Direct i18next usage
- `const { t } = useTranslation()` - React hook
- `<Trans i18nKey="key" />` - React component

## File Structure

Translation files should follow this structure:

**JSON** (`locales/en.json`):
```json
{
  "user": {
    "welcome": "Welcome",
    "greeting": "Hello, {{name}}!"
  },
  "errors": {
    "notFound": "Not found"
  }
}
```

**YAML** (`locales/en.yml`):
```yaml
user:
  welcome: Welcome
  greeting: Hello, {{name}}!
errors:
  notFound: Not found
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Inspired by [js-i18n.nvim](https://github.com/nabekou29/js-i18n.nvim)
- Built with [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) and [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
