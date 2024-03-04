local log = require "obsidian.log"

---@param client obsidian.Client
return function(client, data)
  if not data.args or string.len(data.args) == 0 then
    local picker = client:picker()
    if not picker then
      log.err "No picker configured"
      return
    end

    picker:find_notes()
  else
    client:resolve_note_async_with_picker_fallback(data.args, function(note)
      client:open_note(note)
    end)
  end
end
