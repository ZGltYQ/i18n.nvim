---@class i18n.debounce
local M = {}

---Validates debounce function and timeout
---@param fn function
---@param ms number
local function validate(fn, ms)
  vim.validate {
    fn = { fn, "f" },
    ms = {
      ms,
      function(v)
        return type(v) == "number" and v > 0
      end,
      "number > 0",
    },
  }
end

---Debounces a function on the trailing edge. Automatically `schedule_wrap()`s.
---
---@param fn function Function to debounce
---@param ms number Timeout in ms
---@param first? boolean Whether to use the arguments of the first call to `fn` within the timeframe. Default: Use arguments of the last call.
---@return function wrapped_fn Debounced function
---@return userdata timer Timer handle. Remember to call `timer:close()` at the end or you will leak memory!
function M.debounce_trailing(fn, ms, first)
  validate(fn, ms)
  local timer = vim.loop.new_timer()
  local wrapped_fn

  if not first then
    function wrapped_fn(...)
      local argv = { ... }
      local argc = select("#", ...)

      timer:start(ms, 0, function()
        pcall(vim.schedule_wrap(fn), unpack(argv, 1, argc))
      end)
    end
  else
    local argv, argc
    function wrapped_fn(...)
      argv = argv or { ... }
      argc = argc or select("#", ...)

      timer:start(ms, 0, function()
        pcall(vim.schedule_wrap(fn), unpack(argv, 1, argc))
      end)
    end
  end
  return wrapped_fn, timer
end

---Throttles a function on the leading edge. Automatically `schedule_wrap()`s.
---
---@param fn function Function to throttle
---@param ms number Timeout in ms
---@return function throttled_fn Throttled function
---@return userdata timer Timer handle. Remember to call `timer:close()` at the end or you will leak memory!
function M.throttle_leading(fn, ms)
  validate(fn, ms)
  local timer = vim.loop.new_timer()
  local running = false

  local function wrapped_fn(...)
    if not running then
      timer:start(ms, 0, function()
        running = false
      end)
      running = true
      pcall(vim.schedule_wrap(fn), select(1, ...))
    end
  end
  return wrapped_fn, timer
end

---Throttles a function on the trailing edge. Automatically `schedule_wrap()`s.
---
---@param fn function Function to throttle
---@param ms number Timeout in ms
---@return function throttled_fn Throttled function
---@return userdata timer Timer handle. Remember to call `timer:close()` at the end or you will leak memory!
function M.throttle_trailing(fn, ms)
  validate(fn, ms)
  local timer = vim.loop.new_timer()
  local running = false

  local function wrapped_fn(...)
    timer:start(ms, 0, function()
      running = false
    end)
    if not running then
      running = true
      pcall(vim.schedule_wrap(fn), select(1, ...))
    end
  end
  return wrapped_fn, timer
end

return M
