local log = require "obsidian.log"

---@param client obsidian.Client
return function(client, data)
  local picker = client:picker()
  if not picker then
    log.err "No picker configured"
    return
  end

  if not data.args or string.len(data.args) == 0 then
    picker:find_notes()
    return
  end

  client:resolve_note_async(data.args, function(...)
    local notes = { ... }
    if #notes == 0 then
      log.err("No notes matching '%s'", data.args)
      return
    elseif #notes == 1 then
      return client:open_note(notes[1])
    end

    vim.schedule(function()
      picker:pick_note(notes, {
        callback = function(note)
          client:open_note(note)
        end,
      })
    end)
  end, { search = { sort = true } })
end
