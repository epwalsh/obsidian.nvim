local util = require "obsidian.util"
local log = require "obsidian.log"

---@param client obsidian.Client
return function(client, data)
  local offset_days = 0
  local arg = util.string_replace(data.args, " ", "")
  if string.len(arg) > 0 then
    local offset = tonumber(arg)
    if offset == nil then
      log.err "Invalid argument, expected an integer offset"
      return
    else
      offset_days = offset
    end
  end
  local note = client:daily(offset_days)
  local open_in = util.get_open_strategy(client.opts.open_notes_in)
  vim.api.nvim_command(open_in .. tostring(note.path))
end
