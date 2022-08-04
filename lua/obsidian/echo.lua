local echo = {}

local HlInfo = "ObsidianInfo"
local HlWarn = "ObsidianWarn"
local HlError = "ObsidianError"

---Define highlight groups.
echo.setup = function()
  vim.api.nvim_set_hl(0, HlInfo, { link = "Question" })
  vim.api.nvim_set_hl(0, HlWarn, { link = "WarningMsg" })
  vim.api.nvim_set_hl(0, HlError, { link = "ErrorMsg" })
end

---Echo a message with a highlight group.
---
---@param msg any
---@param group string
echo.echo = function(msg, group)
  vim.api.nvim_echo({ { "[Obsidian] ", group }, { tostring(msg), nil } }, true, {})
end

echo.info = function(msg)
  echo.echo(msg, HlInfo)
end

echo.warn = function(msg)
  echo.echo(msg, HlWarn)
end

echo.err = function(msg)
  echo.echo(msg, HlError)
end

echo.fail = function(msg)
  error("[Obsidian] " .. msg)
end

return echo
