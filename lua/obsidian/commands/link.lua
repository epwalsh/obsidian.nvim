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
    client:update_ui()
  end

  -- Try to resolve the search term to a single note.
  client:resolve_note_async(search_term, function(...)
    local notes = { ... }

    if #notes == 0 then
      log.err("No notes matching '%s'", search_term)
      return
    elseif #notes == 1 then
      return vim.schedule(function()
        insert_ref(notes[1])
      end)
    end

    return vim.schedule(function()
      -- Otherwise run the preferred picker to search for notes.
      local picker = client:picker()
      if not picker then
        log.err("Found multiple notes matches '%s', but no picker is configured", search_term)
        return
      end

      picker:pick_note(notes, {
        prompt_title = "Select note to link",
        callback = function(note)
          insert_ref(note)
        end,
      })
    end)
  end)
end
