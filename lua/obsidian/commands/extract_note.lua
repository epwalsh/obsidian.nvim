local log = require "obsidian.log"
local util = require "obsidian.util"

---Extract the selected text into a new note
---and replace the selection with a link to the new note.
---
---@param client obsidian.Client
return function(client, data)
  local viz = util.get_visual_selection()
  if viz.lines == nil or #viz.lines == 0 then
    log.err "ObsidianExtractNote must be called with visual selection"
    return
  end

  local content
  if data.args ~= nil and string.len(data.args) > 0 then
    content = { data.args }
  else
    content = viz.lines
  end

  -- new note with title from user
  local title = vim.fn.input { prompt = "Enter title (optional): " }
  if string.len(title) == 0 then
    title = nil
  end
  local note = client:new_note(title)

  -- replace selection with link to new note
  local link = client:format_link(note)
  vim.api.nvim_buf_set_lines(0, viz.csrow - 1, viz.cerow + 1, false, { link })

  -- add the selected text to the end of the new note
  local open_in = util.get_open_strategy(client.opts.open_notes_in)
  vim.cmd(open_in .. tostring(note.path))
  vim.api.nvim_buf_set_lines(0, -1, -1, false, content)
end
