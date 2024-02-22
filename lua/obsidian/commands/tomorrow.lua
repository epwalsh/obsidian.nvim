---@param client obsidian.Client
return function(client, _)
  local note = client:tomorrow()
  client:open_note(note)
end
