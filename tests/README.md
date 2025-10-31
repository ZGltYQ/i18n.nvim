# Tests

Tests for i18n.nvim using plenary.nvim test framework.

## Running Tests

To run all tests:

```bash
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

To run a specific test file:

```bash
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/i18n/utils_spec.lua"
```

## Test Structure

- `minimal_init.lua` - Minimal Neovim configuration for tests
- `i18n/` - Tests for i18n modules
  - `utils_spec.lua` - Tests for utility functions
  - `config_spec.lua` - Tests for configuration
  - `translation_source_spec.lua` - Tests for translation file loading
  - `analyzer_spec.lua` - Tests for Treesitter analyzer
  - `translator_spec.lua` - Tests for translation services

## Test Requirements

- Neovim 0.10.0+
- plenary.nvim
- nvim-treesitter (for analyzer tests)

## Writing Tests

Follow the plenary.nvim test format:

```lua
describe('module_name', function()
  describe('function_name', function()
    it('should do something', function()
      assert.are.equal(expected, actual)
    end)
  end)
end)
```
