local log = {}

log._log_level = vim.log.levels.INFO

---@type { msg: string, level: integer }[]
local buffer = {}

---@param t table
---@return boolean
local function has_tostring(t)
  local mt = getmetatable(t)
  return mt ~= nil and mt.__tostring ~= nil
end

---@param msg string
---@return any[]
local function message_args(msg, ...)
  local args = { ... }
  local num_directives = select(2, string.gsub(msg, "%%", "")) - 2 * select(2, string.gsub(msg, "%%%%", ""))

  -- Some elements might be nil, so we can't use 'ipairs'.
  local out = {}
  for i = 1, #args do
    local v = args[i]
    if v == nil then
      out[i] = tostring(v)
    elseif type(v) == "table" and not has_tostring(v) then
      out[i] = vim.inspect(v)
    else
      out[i] = v
    end
  end

  -- If were short formatting args relative to the number of directives, add "nil" strings on.
  if #out < num_directives then
    for i = #out + 1, num_directives do
      out[i] = "nil"
    end
  end

  return out
end

---@param level integer
log.set_level = function(level)
  log._log_level = level
end

---Log a message.
---
---@param msg any
---@param level integer|?
log.log = function(msg, level, ...)
  if level == nil or log._log_level == nil or level >= log._log_level then
    msg = string.format(tostring(msg), unpack(message_args(msg, ...)))
    if vim.in_fast_event() then
      vim.schedule(function()
        vim.notify(msg, level, { title = "Obsidian.nvim" })
      end)
    else
      vim.notify(msg, level, { title = "Obsidian.nvim" })
    end
  end
end

---@param msg string
---@param level integer
log.lazy_log = function(msg, level, ...)
  msg = string.format(tostring(msg), unpack(message_args(msg, ...)))
  buffer[#buffer + 1] = { msg = msg, level = level }
end

--- Flush lazy logs.
---
---@param opts { raw_print: boolean|? }|?
log.flush = function(opts)
  local util = require "obsidian.util"

  opts = opts or {}

  ---@type integer|?
  local level
  ---@type string[]
  local messages = {}
  local n = #buffer
  for i, record in ipairs(buffer) do
    if level ~= nil and level ~= record.level then
      -- flush messages for current log level
      if opts.raw_print then
        print(table.concat(messages, "\n"))
      else
        log.log(table.concat(messages, "\n"), level)
      end
      util.tbl_clear(messages)
    end

    messages[#messages + 1] = record.msg
    level = record.level

    if i == n then
      -- flush remaining messages
      if opts.raw_print then
        print(table.concat(messages, "\n"))
      else
        log.log(table.concat(messages, "\n"), level)
      end
    end
  end

  util.tbl_clear(buffer)
end

---Log a message only once.
---
---@param msg any
---@param level integer|?
log.log_once = function(msg, level, ...)
  if level == nil or log._log_level == nil or level >= log._log_level then
    msg = string.format(tostring(msg), unpack(message_args(...)))
    if vim.in_fast_event() then
      vim.schedule(function()
        vim.notify_once(msg, level, { title = "Obsidian.nvim" })
      end)
    else
      vim.notify_once(msg, level, { title = "Obsidian.nvim" })
    end
  end
end

---@param msg string
log.debug = function(msg, ...)
  log.log(msg, vim.log.levels.DEBUG, ...)
end

---@param msg string
log.info = function(msg, ...)
  log.log(msg, vim.log.levels.INFO, ...)
end

log.lazy_info = function(msg, ...)
  log.lazy_log(msg, vim.log.levels.INFO, ...)
end

---@param msg string
log.warn = function(msg, ...)
  log.log(msg, vim.log.levels.WARN, ...)
end

log.lazy_warn = function(msg, ...)
  log.lazy_log(msg, vim.log.levels.WARN, ...)
end

---@param msg string
log.warn_once = function(msg, ...)
  log.log_once(msg, vim.log.levels.WARN, ...)
end

---@param msg string
log.err = function(msg, ...)
  log.log(msg, vim.log.levels.ERROR, ...)
end

log.error = log.err

---@param msg string
log.err_once = function(msg, ...)
  log.log_once(msg, vim.log.levels.ERROR, ...)
end

log.error_once = log.err

log.lazy_err = function(msg, ...)
  log.lazy_log(msg, vim.log.levels.ERROR, ...)
end

log.lazy_error = log.lazy_err

return log
