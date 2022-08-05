local obsidian = require "obsidian"
local Path = require "plenary.path"

local source = {}

source.new = function()
  return setmetatable({}, { __index = source })
end

source.get_trigger_characters = obsidian.completion.get_trigger_characters

source.get_keyword_pattern = obsidian.completion.get_keyword_pattern

source.complete = function(self, request, callback)
  local opts = self:option(request)
  local can_complete, search, insert_start, insert_end = obsidian.completion.can_complete(request)

  if can_complete and search ~= nil and #search >= opts.completion.min_chars then
    local new_id = obsidian.util.zettel_id()
    local items = {}
    table.insert(items, {
      sortText = "[[" .. search,
      label = "Create: [[" .. new_id .. "|" .. search .. "]]",
      kind = 18,
      textEdit = {
        newText = "[[" .. new_id .. "|" .. search .. "]]",
        insert = {
          start = {
            line = request.context.cursor.row - 1,
            character = insert_start,
          },
          ["end"] = {
            line = request.context.cursor.row - 1,
            character = insert_end,
          },
        },
      },
      data = {
        dir = opts.dir,
        id = new_id,
        title = search,
      },
    })
    return callback {
      items = items,
      isIncomplete = true,
    }
  else
    return callback { isIncomplete = true }
  end
end

---@diagnostic disable-next-line: unused-local
source.execute = function(self, item, callback)
  local data = item.data
  ---@type Path
  ---@diagnostic disable-next-line: assign-type-mismatch
  local path = Path:new(data.dir) / (data.id .. ".md")
  local note = obsidian.note.new(data.id, { data.title }, {}, path)
  note:save()
  obsidian.echo.info("Created note " .. tostring(note.id) .. " at " .. tostring(note.path))
  return callback
end

---Get opts.
---
---@return obsidian.config.ClientOpts
source.option = function(_, params)
  return obsidian.config.ClientOpts.normalize(params.option)
end

return source
