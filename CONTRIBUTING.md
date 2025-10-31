# Contributing to i18n.nvim

Thank you for your interest in contributing to i18n.nvim! This document provides guidelines for contributing to the project.

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/i18n.nvim.git
   cd i18n.nvim
   ```

2. Install dependencies:
   - Neovim 0.10.0+
   - nvim-treesitter
   - plenary.nvim
   - Optional: jq, yq

3. Install the plugin locally in your Neovim config:
   ```lua
   {
     dir = '/path/to/i18n.nvim',
     dependencies = {
       'nvim-treesitter/nvim-treesitter',
       'nvim-lua/plenary.nvim',
     },
     config = function()
       require('i18n').setup()
     end,
   }
   ```

## Project Structure

```
i18n.nvim/
├── lua/i18n/              # Main plugin code
│   ├── init.lua           # Plugin entry point
│   ├── config.lua         # Configuration management
│   ├── utils.lua          # Utility functions
│   ├── analyzer.lua       # Treesitter-based key detection
│   ├── translation_source.lua  # Translation file parsing
│   ├── virtual_text.lua   # Virtual text display
│   ├── editor.lua         # Translation editing
│   ├── commands.lua       # User commands
│   └── translator/        # Translation services
│       ├── init.lua       # Translation orchestrator
│       ├── base.lua       # Base translator interface
│       ├── google.lua     # Google Translate
│       └── deepl.lua      # DeepL
├── plugin/               # Auto-load plugin
├── queries/              # Treesitter queries
├── tests/                # Test suite
└── README.md             # Documentation
```

## Making Changes

1. Create a new branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes

3. Run tests:
   ```bash
   nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/"
   ```

4. Format code (if applicable)

5. Commit your changes:
   ```bash
   git commit -m "feat: add new feature"
   ```

## Commit Message Guidelines

Follow conventional commits:

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `test:` - Test changes
- `refactor:` - Code refactoring
- `chore:` - Maintenance tasks

## Adding New Translation Services

To add a new translation service:

1. Create a new file in `lua/i18n/translator/` (e.g., `my_service.lua`)

2. Implement the translator class:
   ```lua
   local BaseTranslator = require('i18n.translator.base').BaseTranslator

   local MyServiceTranslator = setmetatable({}, { __index = BaseTranslator })

   function MyServiceTranslator:new()
     local obj = BaseTranslator:new('my_service')
     setmetatable(obj, self)
     return obj
   end

   function MyServiceTranslator:translate(text, from_lang, to_lang)
     -- Implementation here
     return translated_text, nil
   end

   function M.new()
     return MyServiceTranslator:new()
   end

   return M
   ```

3. Add configuration in `config.lua` defaults

4. Update documentation

## Code Style

- Use 2 spaces for indentation
- Add LuaDoc comments for functions
- Follow existing code style
- Keep functions focused and small

## Pull Request Process

1. Update README.md with details of changes if applicable
2. Update documentation
3. Add tests for new features
4. Ensure all tests pass
5. Get at least one review from a maintainer

## Reporting Bugs

When reporting bugs, please include:

- Neovim version
- Plugin version
- Steps to reproduce
- Expected behavior
- Actual behavior
- Error messages (if any)

## Feature Requests

Feature requests are welcome! Please:

- Check if the feature already exists
- Describe the use case
- Explain why it would be useful
- Be open to discussion

## Questions?

Feel free to open an issue for questions or discussions.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
