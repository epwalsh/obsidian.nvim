local echo = {}

---Echo a message.
---
---@param msg any
---@param level integer|?
echo.echo = function(msg, level)
  msg = "[Obsidian] " .. tostring(msg)
  if vim.in_fast_event() then
    vim.schedule(function()
      vim.notify(msg, level)
    end)
  else
    vim.notify(msg, level)
  end
end

---Echo a message with a highlight group.
---
---@param msg any
---@param level integer|?
echo.echo_once = function(msg, level)
  msg = "[Obsidian] " .. tostring(msg)
  if vim.in_fast_event() then
    vim.schedule(function()
      vim.notify_once(msg, level)
    end)
  else
    vim.notify_once(msg, level)
  end
end

---@param msg string
---@param log_level integer|?
echo.info = function(msg, log_level)
  if log_level == nil or log_level <= vim.log.levels.INFO then
    echo.echo(msg, vim.log.levels.INFO)
  end
end

---@param msg any
---@param log_level integer|?
echo.warn = function(msg, log_level)
  if log_level == nil or log_level <= vim.log.levels.WARN then
    echo.echo(msg, vim.log.levels.WARN)
  end
end

---@param msg any
---@param log_level integer|?
echo.warn_once = function(msg, log_level)
  if log_level == nil or log_level <= vim.log.levels.WARN then
    echo.echo_once(msg, vim.log.levels.WARN)
  end
end

---@param msg any
---@param log_level integer|?
echo.err = function(msg, log_level)
  if log_level == nil or log_level <= vim.log.levels.ERROR then
    echo.echo(msg, vim.log.levels.ERROR)
  end
end

---@param msg any
---@param log_level integer|?
echo.err_once = function(msg, log_level)
  if log_level == nil or log_level <= vim.log.levels.ERROR then
    echo.echo_once(msg, vim.log.levels.ERROR)
  end
end

---@param msg any
echo.fail = function(msg)
  error("[Obsidian] " .. msg)
end

return echo
