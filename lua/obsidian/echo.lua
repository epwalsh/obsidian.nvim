local echo = {}

---Echo a message with a highlight group.
---
---@param msg any
---@param level integer
echo.echo = function(msg, level)
  vim.notify("[Obsidian] " .. tostring(msg), level)
end

---@param msg string
---@param client obsidian.Client|nil
echo.info = function(msg, client)
  if client == nil or client.opts.silent == false then
    echo.echo(msg, vim.log.levels.INFO)
  end
end

echo.warn = function(msg)
  echo.echo(msg, vim.log.levels.WARN)
end

echo.err = function(msg)
  echo.echo(msg, vim.log.levels.ERROR)
end

echo.fail = function(msg)
  error("[Obsidian] " .. msg)
end

return echo
