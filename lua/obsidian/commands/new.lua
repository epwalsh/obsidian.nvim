local util = require "obsidian.util"
local log = require "obsidian.log"

---@param client obsidian.Client
return function(client, data)
  ---@type obsidian.Note
  local note
  if data.args:len() > 0 then
    note = client:create_note { title = data.args, no_write = true }
  else
    local title = util.input "Enter title or path (optional): "
    if not title then
      log.warn "Aborted"
      return
    elseif title == "" then
      title = nil
    end
    note = client:create_note { title = title, no_write = true }
  end

  -- Open the note in a new buffer.
  client:open_note(note, { sync = true })
  client:write_note_to_buffer(note)
end
