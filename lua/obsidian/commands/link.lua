local Note = require "obsidian.note"
local util = require "obsidian.util"
local log = require "obsidian.log"

---@param client obsidian.Client
return function(client, data)
  local viz = util.get_visual_selection()
  if not viz then
    log.err "ObsidianLink must be called with visual selection"
    return
  elseif #viz.lines ~= 1 then
    log.err "Only in-line visual selections allowed"
    return
  end

  local line = assert(viz.lines[1])

  ---@type string
  local search_term
  if data.args ~= nil and string.len(data.args) > 0 then
    search_term = data.args
  else
    search_term = viz.selection
  end

  ---@param note obsidian.Note
  local function insert_ref(note)
    local new_line = string.sub(line, 1, viz.cscol - 1)
      .. client:format_link(note, { label = viz.selection })
      .. string.sub(line, viz.cecol + 1)
    vim.api.nvim_buf_set_lines(0, viz.csrow - 1, viz.csrow, false, { new_line })
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

  picker:grep_notes {
    prompt_title = "Link note",
    query = search_term,
    no_default_mappings = true,
    callback = function(path)
      insert_ref(Note.from_file(path))
      client:update_ui()
    end,
  }
end
