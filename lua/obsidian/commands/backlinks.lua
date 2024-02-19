local util = require "obsidian.util"
local log = require "obsidian.log"
local search = require "obsidian.search"
local RefTypes = require("obsidian.search").RefTypes
local LocationList = require "obsidian.location_list"
local Note = require "obsidian.note"
local iter = require("obsidian.itertools").iter

local NAMESPACE = "ObsidianBacklinks"

---@param client obsidian.Client
---@param note obsidian.Note
local function gather_backlinks_location_list(client, note)
  client:find_backlinks_async(note, true, function(backlink_matches)
    if vim.tbl_isempty(backlink_matches) then
      log.warn("No backlinks to '%s'", note.id)
      return
    end

    local loclist = LocationList.new(client, vim.fn.bufnr(), vim.fn.winnr(), NAMESPACE, client.opts.backlinks)

    local view_lines = {}
    local highlights = {}
    local folds = {}

    for match in iter(backlink_matches) do
      -- Header for note.
      view_lines[#view_lines + 1] = (" %s"):format(match.note:display_name())
      highlights[#highlights + 1] = { group = "CursorLineNr", line = #view_lines - 1, col_start = 0, col_end = 1 }
      highlights[#highlights + 1] = { group = "Directory", line = #view_lines - 1, col_start = 2, col_end = -1 }

      local display_path = assert(client:vault_relative_path(match.note.path))

      -- Line for backlink within note.
      for line_match in iter(match.matches) do
        local text, ref_indices, ref_strs = search.find_and_replace_refs(line_match.text)
        local text_start = 4 + display_path:len() + tostring(line_match.line):len()
        view_lines[#view_lines + 1] = ("  %s:%s:%s"):format(display_path, line_match.line, text)

        -- Add highlights for all refs in the text.
        for i, ref_idx in ipairs(ref_indices) do
          local ref_str = ref_strs[i]
          if string.find(ref_str, tostring(note.id), 1, true) ~= nil then
            highlights[#highlights + 1] = {
              group = "Search",
              line = #view_lines - 1,
              col_start = text_start + ref_idx[1] - 1,
              col_end = text_start + ref_idx[2],
            }
          end
        end

        -- Add highlight for path and line number
        highlights[#highlights + 1] = {
          group = "Comment",
          line = #view_lines - 1,
          col_start = 2,
          col_end = text_start,
        }
      end

      folds[#folds + 1] = { range = { #view_lines - #match.matches, #view_lines } }
      view_lines[#view_lines + 1] = ""
    end

    -- Remove last blank line.
    view_lines[#view_lines] = nil

    loclist:render(view_lines, folds, highlights)

    log.info(
      "Showing backlinks to '%s'.\n\n"
        .. "TIPS:\n\n"
        .. "- Hit ENTER on a match to follow the backlink\n"
        .. "- Hit ENTER on a group header to toggle the fold, or use normal fold mappings",
      note.id
    )
  end)
end

---@param client obsidian.Client
return function(client, _)
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

  return gather_backlinks_location_list(client, note)
end
