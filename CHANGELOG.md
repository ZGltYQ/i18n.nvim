# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of i18n.nvim
- Inline translation display with virtual text
- Treesitter-based translation key detection
- Support for i18next, react-i18next, and next-i18next
- Translation editing via `:I18nEdit` command
- **Quick add from selection**: Select text, press hotkey, auto-translate to all languages (`:I18nAddFromSelection`)
- Auto-translation with Google Translate (free and API)
- Auto-translation with DeepL API
- JSON and YAML translation file support
- Virtual text toggle commands
- Translation key copy to clipboard
- Multi-language project support
- Configurable virtual text display
- Diagnostic warnings for missing translations
- Commands:
  - `:I18nSetLang` - Set display language
  - `:I18nEdit` - Edit translation at cursor
  - `:I18nAddFromSelection` - Add translation from selected text with auto-translation
  - `:I18nTranslate` - Auto-translate buffer
  - `:I18nTranslateAll` - Auto-translate project
  - `:I18nTranslateKey` - Translate specific key
  - `:I18nVirtualText[Enable|Disable|Toggle]` - Control virtual text
  - `:I18nReload` - Reload translation files
  - `:I18nCopyKey` - Copy translation key
  - `:I18nListLanguages` - List available languages
  - `:I18nInfo` - Show translation info

### Dependencies
- Neovim >= 0.10.0
- nvim-treesitter
- plenary.nvim
- Optional: jq (for JSON editing)
- Optional: yq (for YAML editing)

## [1.0.0] - YYYY-MM-DD (Future)

First stable release

[Unreleased]: https://github.com/your-username/i18n.nvim/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/your-username/i18n.nvim/releases/tag/v1.0.0
