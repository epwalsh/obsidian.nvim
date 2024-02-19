local util = require "obsidian.util"
local log = require "obsidian.log"
local RefTypes = require("obsidian.search").RefTypes
local Note = require "obsidian.note"

---@param client obsidian.Client
return function(client, _)
  local picker = assert(client:picker())
  if not picker then
    log.err "No picker configured"
    return
  end

  ---@type obsidian.Note|?
  local note
  local cursor_link, _, ref_type = util.parse_cursor_link()
  if cursor_link ~= nil and ref_type ~= RefTypes.NakedUrl and ref_type ~= RefTypes.FileUrl then
    note = client:resolve_note(cursor_link)
    if note == nil then
      log.err "Could not resolve link under cursor to a note ID, path, or alias"
      return
    end
  else
    note = Note.from_file(vim.api.nvim_buf_get_name(0))
  end

  assert(note)

  client:find_backlinks_async(note, true, function(backlinks)
    local entries = {}
    for _, matches in ipairs(backlinks) do
      for _, match in ipairs(matches.matches) do
        local display = string.format("%s [%s] %s", matches.note:display_name(), match.line, match.text)
        entries[#entries + 1] = {
          value = { path = matches.path, line = match.line },
          display = display,
          ordinal = display,
          filename = matches.path,
          lnum = match.line,
        }
      end
    end

    vim.schedule(function()
      picker:pick(entries, {
        prompt_title = "Backlinks",
        callback = function(value)
          vim.cmd(string.format("e %s", value.path))
          vim.api.nvim_win_set_cursor(0, { tonumber(value.line), 0 })
        end,
      })
    end)
  end)
end
