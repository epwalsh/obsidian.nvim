local log = require "obsidian.log"
local util = require "obsidian.util"
local search = require "obsidian.search"

---@param client obsidian.Client
---@param picker obsidian.Picker
---@param tags string[]
local function gather_tag_picker_list(client, picker, tags)
  client:find_tags_async(tags, function(tag_locations)
    if vim.tbl_isempty(tag_locations) then
      log.warn "Tags not found"
      return
    end

    -- Format results into picker entries, filtering out results that aren't exact matches or sub-tags.
    ---@type obsidian.PickerEntry[]
    local entries = {}
    for _, tag_loc in ipairs(tag_locations) do
      for _, tag in ipairs(tags) do
        if tag_loc.tag == tag or vim.startswith(tag_loc.tag, tag .. "/") then
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
          util.open_buffer(value.path, { line = value.line, col = value.col })
        end,
      })
    end)
  end, { search = { sort = true } })
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
    local viz = util.get_visual_selection()
    if viz and #viz.lines == 1 and string.match(viz.selection, "^#?" .. search.Patterns.TagCharsRequired .. "$") then
      local tag = viz.selection

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
    client:list_tags_async(nil, function(all_tags)
      vim.schedule(function()
        -- Open picker with tags.
        picker:pick_tag(all_tags, {
          callback = function(...)
            gather_tag_picker_list(client, picker, { ... })
          end,
          allow_multiple = true,
        })
      end)
    end)
  end
end
