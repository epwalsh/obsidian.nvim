local util = require "obsidian.util"

---@param client obsidian.Client
return function(client, _)
  local note = client:tomorrow()
  local open_in = util.get_open_strategy(client.opts.open_notes_in)
  vim.api.nvim_command(open_in .. tostring(note.path))
end
