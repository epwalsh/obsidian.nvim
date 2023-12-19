local log = require "obsidian.log"

---@param client obsidian.Client
return function(client, data)
  local _, csrow, cscol, _ = unpack(vim.fn.getpos "'<")
  local _, cerow, cecol, _ = unpack(vim.fn.getpos "'>")

  if data.line1 ~= csrow or data.line2 ~= cerow then
    log.err "ObsidianLink must be called with visual selection"
    return
  end

  local lines = vim.fn.getline(csrow, cerow)
  if #lines ~= 1 then
    log.err "Only in-line visual selections allowed"
    return
  end

  local line = lines[1]

  local title
  if string.len(data.args) > 0 then
    title = data.args
  else
    title = string.sub(line, cscol, cecol)
  end
  local note = client:new_note(title, nil, vim.fn.expand "%:p:h")

  line = string.sub(line, 1, cscol - 1)
    .. "[["
    .. tostring(note.id)
    .. "|"
    .. string.sub(line, cscol, cecol)
    .. "]]"
    .. string.sub(line, cecol + 1)
  vim.api.nvim_buf_set_lines(0, csrow - 1, csrow, false, { line })
end
