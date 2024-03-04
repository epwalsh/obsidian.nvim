local util = require "obsidian.util"
local log = require "obsidian.log"
local RefTypes = require("obsidian.search").RefTypes

---@param client obsidian.Client
---@param picker obsidian.Picker
---@param note obsidian.Note
local function collect_backlinks(client, picker, note)
  client:find_backlinks_async(note, function(backlinks)
    if vim.tbl_isempty(backlinks) then
      log.info "No backlinks found"
      return
    end

    local entries = {}
    for _, matches in ipairs(backlinks) do
      for _, match in ipairs(matches.matches) do
        entries[#entries + 1] = {
          value = { path = matches.path, line = match.line },
          filename = tostring(matches.path),
          lnum = match.line,
        }
      end
    end

    vim.schedule(function()
      picker:pick(entries, {
        prompt_title = "Backlinks",
        callback = function(value)
          util.open_buffer(value.path, { line = value.line })
        end,
      })
    end)
  end, { search = { sort = true } })
end

---@param client obsidian.Client
return function(client, _)
  local picker = assert(client:picker())
  if not picker then
    log.err "No picker configured"
    return
  end

  local cursor_link, _, ref_type = util.parse_cursor_link()
  if cursor_link ~= nil and ref_type ~= RefTypes.NakedUrl and ref_type ~= RefTypes.FileUrl then
    client:resolve_note_async(cursor_link, function(...)
      local notes = { ... }

      if #notes == 0 then
        log.err("No notes matching '%s'", cursor_link)
        return
      elseif #notes == 1 then
        return collect_backlinks(client, picker, notes[1])
      else
        return vim.schedule(function()
          picker:pick_note(notes, {
            prompt_title = "Select note",
            callback = function(note)
              collect_backlinks(client, picker, note)
            end,
          })
        end)
      end
    end)
  else
    local note = client:current_note()
    if note == nil then
      log.err "Current buffer does not appear to be a note inside the vault"
    else
      collect_backlinks(client, picker, note)
    end
  end
end
