local util = require "obsidian.util"
local log = require "obsidian.log"
local RefTypes = require("obsidian.search").RefTypes

---@param client obsidian.Client
---@param picker obsidian.Picker
---@param note obsidian.Note
---@param opts { anchor: string|?, block: string|? }|?
local function collect_backlinks(client, picker, note, opts)
  opts = opts or {}

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
  end, { search = { sort = true }, anchor = opts.anchor, block = opts.block })
end

---@param client obsidian.Client
return function(client)
  local picker = assert(client:picker())
  if not picker then
    log.err "No picker configured"
    return
  end

  local location, _, ref_type = util.parse_cursor_link()

  if location ~= nil and ref_type ~= RefTypes.NakedUrl and ref_type ~= RefTypes.FileUrl then
    -- Remove block links from the end if there are any.
    -- TODO: handle block links.
    ---@type string|?
    local block_link
    location, block_link = util.strip_block_links(location)

    -- Remove anchor links from the end if there are any.
    ---@type string|?
    local anchor_link
    location, anchor_link = util.strip_anchor_links(location)

    -- Assume 'location' is current buffer path if empty, like for TOCs.
    if string.len(location) == 0 then
      location = vim.api.nvim_buf_get_name(0)
    end

    local opts = { anchor = anchor_link, block = block_link }

    client:resolve_note_async(location, function(...)
      ---@type obsidian.Note[]
      local notes = { ... }

      if #notes == 0 then
        log.err("No notes matching '%s'", location)
        return
      elseif #notes == 1 then
        return collect_backlinks(client, picker, notes[1], opts)
      else
        return vim.schedule(function()
          picker:pick_note(notes, {
            prompt_title = "Select note",
            callback = function(note)
              collect_backlinks(client, picker, note, opts)
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
