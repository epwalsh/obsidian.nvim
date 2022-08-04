local obsidian = require "obsidian"
local Path = require "plenary.path"

local source = {}

source.new = function()
  return setmetatable({}, { __index = source })
end

source.get_trigger_characters = obsidian.completion.get_trigger_characters

source.get_keyword_pattern = obsidian.completion.get_keyword_pattern

source.complete = function(self, request, callback)
  local dir = self:option(request).dir
  if dir == nil then
    error "Obsidian completion has not been setup correctly!"
  end

  local can_complete, search, insert_start, insert_end = obsidian.completion.can_complete(request)

  if can_complete then
    assert(search ~= nil)
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
        dir = dir,
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

source.execute = function(self, item, callback)
  local data = item.data
  ---@type Path
  local path = Path:new(data.dir) / (data.id .. ".md")
  local note = obsidian.note.new(data.id, { data.title }, {}, path)
  note:save()
  print("[Obsidian] Created note", note.id, "at", note.path)
  return callback
end

source.option = function(_, params)
  return vim.tbl_extend("force", {
    dir = "./",
  }, params.option)
end

return source
