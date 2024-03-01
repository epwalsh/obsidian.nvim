local log = require "obsidian.log"

---@param client obsidian.Client
return function(client, data)
  local picker = client:picker()
  if not picker then
    log.err "No picker configured"
    return
  end
  picker:grep_notes { query = data.args }
end
