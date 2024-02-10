local Note = require "obsidian.note"
local log = require "obsidian.log"

---@param client obsidian.Client
return function(client, data)
  local _, csrow, cscol, _ = unpack(assert(vim.fn.getpos "'<"))
  local _, cerow, cecol, _ = unpack(assert(vim.fn.getpos "'>"))

  if data.line1 ~= csrow or data.line2 ~= cerow then
    log.err "ObsidianLink must be called with visual selection"
    return
  end

  local lines = vim.fn.getline(csrow, cerow)
  if #lines ~= 1 then
    log.err "Only in-line visual selections allowed"
    return
  end

  local line = assert(lines[1])

  ---@param note obsidian.Note
  local function insert_ref(note)
    line = string.sub(line, 1, cscol - 1)
      .. "[["
      .. tostring(note.id)
      .. "|"
      .. string.sub(line, cscol, cecol)
      .. "]]"
      .. string.sub(line, cecol + 1)
    vim.api.nvim_buf_set_lines(0, csrow - 1, csrow, false, { line })
  end

  ---@type string
  local search_term
  if string.len(data.args) > 0 then
    search_term = data.args
  else
    search_term = string.sub(line, cscol, cecol)
  end

  -- Try to resolve the search term to a single note.
  local note = client:resolve_note(search_term)

  if note ~= nil then
    return insert_ref(note)
  end

  -- Otherwise run the preferred picker to search for notes.
  local picker = client:picker()
  if not picker then
    log.err "No picker configured"
    return
  end

  picker:grep {
    prompt_title = "Link note",
    query = search_term,
    no_default_mappings = true,
    callback = function(path)
      insert_ref(Note.from_file(path, client.dir))
      client:update_ui()
    end,
  }
end
