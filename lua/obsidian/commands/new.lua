local util = require "obsidian.util"

---@param client obsidian.Client
return function(client, data)
  ---@type obsidian.Note
  local note
  local open_in = util.get_open_strategy(client.opts.open_notes_in)
  if data.args:len() > 0 then
    note = client:new_note(data.args)
  else
    note = client:new_note()
  end
  vim.api.nvim_command(open_in .. tostring(note.path))
end
