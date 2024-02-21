---@param client obsidian.Client
return function(client, data)
  ---@type obsidian.Note
  local note
  if data.args:len() > 0 then
    note = client:new_note(data.args)
  else
    local title = vim.fn.input {
      prompt = "Enter title (optional): ",
    }
    if string.len(title) == 0 then
      title = nil
    end
    note = client:new_note(title)
  end
  client:open_note(note)
end
