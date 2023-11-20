local log = {}

log._log_level = vim.log.levels.INFO

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
    msg = "[Obsidian] " .. string.format(tostring(msg), ...)
    if vim.in_fast_event() then
      vim.schedule(function()
        vim.notify(msg, level, { title = "Obsidian.nvim" })
      end)
    else
      vim.notify(msg, level, { title = "Obsidian.nvim" })
    end
  end
end

---Log a message only once.
---
---@param msg any
---@param level integer|?
log.log_once = function(msg, level, ...)
  if level == nil or log._log_level == nil or level >= log._log_level then
    msg = "[Obsidian] " .. string.format(tostring(msg), ...)
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

---@param msg string
log.warn = function(msg, ...)
  log.log(msg, vim.log.levels.WARN, ...)
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

---@param msg string
log.fail = function(msg, ...)
  error("[Obsidian] " .. string.format(msg, ...))
end

return log
