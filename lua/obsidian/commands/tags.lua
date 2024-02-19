local log = require "obsidian.log"
local util = require "obsidian.util"
local search = require "obsidian.search"

---@param client obsidian.Client
---@param picker obsidian.Picker
---@param tags string[]
local function gather_tag_picker_list(client, picker, tags)
  client:find_tags_async(tags, true, function(tag_locations)
    if vim.tbl_isempty(tag_locations) then
      log.warn "Tags not found"
      return
    end

    -- Format results into picker entries, filtering out results that aren't exact matches.
    ---@type obsidian.PickerEntry[]
    local entries = {}
    for _, tag_loc in ipairs(tag_locations) do
      for _, tag in ipairs(tags) do
        if tag_loc.tag == tag then
          local display = string.format("%s [%s] %s", tag_loc.note:display_name(), tag_loc.line, tag_loc.text)
          entries[#entries + 1] = {
            value = { path = tag_loc.path, line = tag_loc.line, col = tag_loc.tag_start },
            display = display,
            ordinal = display,
            filename = tostring(tag_loc.path),
            lnum = tag_loc.line,
            col = tag_loc.tag_start,
          }
          break
        end
      end
    end

    vim.schedule(function()
      picker:pick(entries, {
        prompt_title = "Tag Locations",
        callback = function(value)
          vim.cmd(string.format("e %s", value.path))
          vim.api.nvim_win_set_cursor(0, { tonumber(value.line), value.col })
        end,
      })
    end)
  end)
end

---@param client obsidian.Client
return function(client, data)
  local picker = client:picker()
  if not picker then
    log.err "No picker configured"
    return
  end

  local tags = data.fargs

  if vim.tbl_isempty(tags) then
    -- Check for visual selection.
    local _, csrow, cscol, _ = unpack(assert(vim.fn.getpos "'<"))
    local _, cerow, cecol, _ = unpack(assert(vim.fn.getpos "'>"))
    if data.line1 == csrow and data.line2 == cerow then
      local lines = vim.fn.getline(csrow, cerow)
      if #lines ~= 1 then
        log.err "Only in-line visual selections allowed"
        return
      end

      local line = assert(lines[1])
      local tag = string.sub(line, cscol, cecol)

      if not string.match(tag, "^#?" .. search.Patterns.TagCharsRequired .. "$") then
        log.err("Visual selection '%s' is not a valid tag", tag)
        return
      end

      if vim.startswith(tag, "#") then
        tag = string.sub(tag, 2)
      end

      tags = { tag }
    else
      -- Otherwise check for a tag under the cursor.
      local tag = util.cursor_tag()
      if tag then
        tags = { tag }
      end
    end
  end

  if not vim.tbl_isempty(tags) then
    return gather_tag_picker_list(client, picker, util.tbl_unique(tags))
  else
    client:list_tags_async(function(all_tags)
      vim.schedule(function()
        -- Open picker with tags.
        picker:pick(all_tags, {
          prompt_title = "Tags",
          callback = function(tag)
            gather_tag_picker_list(client, picker, { tag })
          end,
        })
      end)
    end)
  end
end
