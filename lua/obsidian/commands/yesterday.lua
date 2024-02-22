---@param client obsidian.Client
return function(client, _)
  local note = client:yesterday()
  client:open_note(note)
end
