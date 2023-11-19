local echo = {}

echo._log_level = vim.log.levels.INFO

---@param level integer
echo.set_level = function(level)
  echo._log_level = level
end

---Echo a message.
---
---@param msg any
---@param level integer|?
echo.echo = function(msg, level, ...)
  if level == nil or echo._log_level == nil or level >= echo._log_level then
    msg = "[Obsidian] " .. string.format(tostring(msg), ...)
    if vim.in_fast_event() then
      vim.schedule(function()
        vim.notify(msg, level)
      end)
    else
      vim.notify(msg, level)
    end
  end
end

---Echo a message with a highlight group.
---
---@param msg any
---@param level integer|?
echo.echo_once = function(msg, level, ...)
  if level == nil or echo._log_level == nil or level >= echo._log_level then
    msg = "[Obsidian] " .. string.format(tostring(msg), ...)
    if vim.in_fast_event() then
      vim.schedule(function()
        vim.notify_once(msg, level)
      end)
    else
      vim.notify_once(msg, level)
    end
  end
end

---@param msg string
echo.debug = function(msg, ...)
  echo.echo(msg, vim.log.levels.DEBUG, ...)
end

---@param msg string
echo.info = function(msg, ...)
  echo.echo(msg, vim.log.levels.INFO, ...)
end

---@param msg string
echo.warn = function(msg, ...)
  echo.echo(msg, vim.log.levels.WARN, ...)
end

---@param msg string
echo.warn_once = function(msg, ...)
  echo.echo_once(msg, vim.log.levels.WARN, ...)
end

---@param msg string
echo.err = function(msg, ...)
  echo.echo(msg, vim.log.levels.ERROR, ...)
end

echo.error = echo.err

---@param msg string
echo.err_once = function(msg, ...)
  echo.echo_once(msg, vim.log.levels.ERROR, ...)
end

echo.error_once = echo.err

---@param msg string
echo.fail = function(msg, ...)
  error("[Obsidian] " .. string.format(msg, ...))
end

return echo
