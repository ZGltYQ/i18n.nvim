# New Feature: Quick Add Translation from Selection

## Overview
Added a powerful new feature that allows you to select any text in your editor, press a hotkey, and automatically translate it to all configured languages with a single command.

## How It Works

### User Workflow
1. **Select text** in visual mode (e.g., "Welcome to our app")
2. **Press hotkey** (`<leader>ta`) or run `:I18nAddFromSelection`
3. **Enter translation key** (e.g., `app.welcome`)
4. **Done!** The plugin:
   - Uses the selected text as the primary language translation
   - Auto-translates to all other configured languages
   - Saves to all translation files (JSON/YAML)
   - Shows a success summary

### Example
```vim
" Visual mode: select "Welcome to our app"
<leader>ta
" Prompt: Translation key for "Welcome to our app":
" Enter: app.welcome
" Result:
" ✓ en.json: "Welcome to our app"
" ✓ es.json: "Bienvenido a nuestra aplicación"
" ✓ fr.json: "Bienvenue dans notre application"
" ✓ de.json: "Willkommen in unserer App"
```

## Implementation Details

### Files Modified
1. **lua/i18n/editor.lua**
   - Added `add_from_selection()` function
   - Added `_perform_auto_translation()` helper function
   - Handles text extraction from visual selection
   - Manages translation key input and validation
   - Orchestrates auto-translation workflow

2. **lua/i18n/commands.lua**
   - Added `add_from_selection()` command handler
   - Registered `:I18nAddFromSelection` user command

3. **lua/i18n/init.lua**
   - Exposed `add_from_selection()` in public API

4. **README.md**
   - Added feature to features list
   - Added quick demo section at the top
   - Added detailed usage example
   - Updated keymaps section

5. **CHANGELOG.md**
   - Documented new feature in unreleased section

### Key Functions

#### `editor.add_from_selection(bufnr)`
- Extracts selected text from visual selection
- Validates translation source availability
- Prompts for translation key
- Checks for existing keys (with overwrite confirmation)
- Calls auto-translation workflow

#### `editor._perform_auto_translation(key, source_text, source_lang, languages, bufnr)`
- Sets source language translation
- Iterates through all target languages
- Calls translation API for each language
- Handles translation failures gracefully (uses fallback)
- Updates all translation files
- Shows success summary with translation count

### User Experience Features
- **Visual selection support**: Works with any text selection
- **Multi-line selection**: Handles text spanning multiple lines
- **Duplicate key detection**: Warns before overwriting existing translations
- **Progress feedback**: Shows translation progress and results
- **Error handling**: Graceful fallback to source text on translation errors
- **Virtual text refresh**: Automatically refreshes inline translations after adding

### Integration
- Works seamlessly with existing translation infrastructure
- Uses the same translation services (Google Translate, DeepL)
- Follows the same file update mechanism (jq/yq)
- Maintains consistency with existing commands

## Benefits
1. **Massive time savings**: No manual translation or copying to external tools
2. **Consistency**: All languages updated simultaneously
3. **Developer-friendly**: Quick workflow from text to translated keys
4. **Flexible**: Works with any translation service
5. **Safe**: Warns before overwriting existing translations

## Recommended Keymap
```lua
vim.keymap.set('v', '<leader>ta', '<cmd>I18nAddFromSelection<cr>', { 
  desc = 'Add translation from selection' 
})
```

## Future Enhancements
Potential improvements:
- Batch selection support (multiple selections)
- Translation memory/cache for repeated phrases
- Custom translation service selection per-call
- Undo/redo support for translation additions
- Preview translations before saving

