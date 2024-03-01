local log = require "obsidian.log"

---@param client obsidian.Client
return function(client, _)
  local picker = client:picker()
  if not picker then
    log.err "No picker configured"
    return
  end

  picker:find_notes()
end
