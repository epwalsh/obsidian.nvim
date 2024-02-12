local util = require "obsidian.util"
local log = require "obsidian.log"
local RefTypes = require("obsidian.search").RefTypes

---@param client obsidian.Client
return function(client, _)
  ---@type obsidian.Note|?
  local note
  local cursor_link, _, ref_type = util.parse_cursor_link()
  if cursor_link ~= nil and ref_type ~= RefTypes.NakedUrl then
    note = client:resolve_note(cursor_link)
    if note == nil then
      log.err "Could not resolve link under cursor to a note ID, path, or alias"
      return
    end
  end

  local ok, backlinks = pcall(function()
    return require("obsidian.backlinks").new(client, nil, nil, note)
  end)

  if ok then
    backlinks:view(function(matches)
      if not vim.tbl_isempty(matches) then
        log.info(
          "Showing backlinks to '%s'.\n\n"
            .. "TIPS:\n\n"
            .. "- Hit ENTER on a match to follow the backlink\n"
            .. "- Hit ENTER on a group header to toggle the fold, or use normal fold mappings",
          backlinks.note.id
        )
      else
        if note ~= nil then
          log.warn("No backlinks to '%s'", note.id)
        else
          log.warn "No backlinks to current note"
        end
      end
    end)
  else
    log.err "Backlinks command can only be used from a valid note"
  end
end
