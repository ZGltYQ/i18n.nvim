--- Tests for i18n.utils module

local utils = require('i18n.utils')

describe('utils', function()
  describe('split_key', function()
    it('should split a key by separator', function()
      local parts = utils.split_key('user.profile.name', '.')
      assert.are.same({ 'user', 'profile', 'name' }, parts)
    end)

    it('should handle single part keys', function()
      local parts = utils.split_key('welcome', '.')
      assert.are.same({ 'welcome' }, parts)
    end)

    it('should handle custom separators', function()
      local parts = utils.split_key('user:profile:name', ':')
      assert.are.same({ 'user', 'profile', 'name' }, parts)
    end)
  end)

  describe('join_key', function()
    it('should join key parts', function()
      local key = utils.join_key({ 'user', 'profile', 'name' }, '.')
      assert.are.equal('user.profile.name', key)
    end)

    it('should handle single part', function()
      local key = utils.join_key({ 'welcome' }, '.')
      assert.are.equal('welcome', key)
    end)
  end)

  describe('truncate', function()
    it('should truncate long text', function()
      local text = 'This is a very long text that needs to be truncated'
      local truncated = utils.truncate(text, 20)
      assert.are.equal(20, #truncated)
      assert.is_true(truncated:match('%.%.%.$') ~= nil)
    end)

    it('should not truncate short text', function()
      local text = 'Short text'
      local truncated = utils.truncate(text, 20)
      assert.are.equal(text, truncated)
    end)
  end)

  describe('tbl_get', function()
    it('should get nested value', function()
      local tbl = {
        user = {
          profile = {
            name = 'John',
          },
        },
      }
      local value = utils.tbl_get(tbl, { 'user', 'profile', 'name' })
      assert.are.equal('John', value)
    end)

    it('should return nil for non-existent key', function()
      local tbl = { user = {} }
      local value = utils.tbl_get(tbl, { 'user', 'profile', 'name' })
      assert.is_nil(value)
    end)
  end)

  describe('tbl_set', function()
    it('should set nested value', function()
      local tbl = {}
      utils.tbl_set(tbl, { 'user', 'profile', 'name' }, 'John')
      assert.are.equal('John', tbl.user.profile.name)
    end)

    it('should overwrite existing value', function()
      local tbl = { user = { profile = { name = 'Jane' } } }
      utils.tbl_set(tbl, { 'user', 'profile', 'name' }, 'John')
      assert.are.equal('John', tbl.user.profile.name)
    end)
  end)

  describe('extract_language', function()
    it('should extract language from filename', function()
      assert.are.equal('en', utils.extract_language('en.json'))
      assert.are.equal('es', utils.extract_language('es.json'))
      assert.are.equal('en-US', utils.extract_language('en-US.json'))
      assert.are.equal('pt_BR', utils.extract_language('pt_BR.json'))
    end)

    it('should return nil for invalid filenames', function()
      assert.is_nil(utils.extract_language('translations.json'))
      assert.is_nil(utils.extract_language('index.js'))
    end)
  end)

  describe('escape_pattern', function()
    it('should escape special characters', function()
      local escaped = utils.escape_pattern('user.profile')
      assert.are.equal('user%.profile', escaped)
    end)

    it('should handle multiple special characters', function()
      local escaped = utils.escape_pattern('a*b+c?d')
      assert.are.equal('a%*b%+c%?d', escaped)
    end)
  end)
end)
