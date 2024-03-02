local abc = require "obsidian.abc"
local obsidian = require "obsidian"
local completion = require "obsidian.completion.tags"
local util = require "obsidian.util"
local iter = require("obsidian.itertools").iter

---@class cmp_obsidian_tags.Source : obsidian.ABC
local source = abc.new_class()

source.new = function()
  return source.init()
end

source.get_trigger_characters = completion.get_trigger_characters

source.get_keyword_pattern = completion.get_keyword_pattern

source.complete = function(_, request, callback)
  local client = assert(obsidian.get_client())
  local can_complete, search, in_frontmatter = completion.can_complete(request)

  if not (can_complete and search ~= nil and #search >= client.opts.completion.min_chars) then
    return callback { isIncomplete = true }
  end

  client:find_tags_async(search, function(tag_locs)
    local tags = {}
    for tag_loc in iter(tag_locs) do
      tags[tag_loc.tag] = true
    end

    local items = {}
    for tag, _ in pairs(tags) do
      items[#items + 1] = {
        sortText = "#" .. tag,
        label = "Tag: #" .. tag,
        kind = 1, -- "Text"
        insertText = "#" .. tag,
        data = {
          bufnr = request.context.bufnr,
          in_frontmatter = in_frontmatter,
          line = request.context.cursor.line,
          tag = tag,
        },
      }
    end

    return callback {
      items = items,
      isIncomplete = false,
    }
  end, { search = { sort = false } })
end

source.execute = function(_, item, callback)
  if item.data.in_frontmatter then
    -- Remove the '#' at the start of the tag.
    -- TODO: ideally we should be able to do this by specifying the completion item in the right way,
    -- but I haven't figured out how to do that.
    local line = vim.api.nvim_buf_get_lines(item.data.bufnr, item.data.line, item.data.line + 1, true)[1]
    line = util.string_replace(line, "#" .. item.data.tag, item.data.tag, 1)
    vim.api.nvim_buf_set_lines(item.data.bufnr, item.data.line, item.data.line + 1, true, { line })
  end
  return callback {}
end

return source
