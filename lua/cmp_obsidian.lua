local obsidian = require "obsidian"

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

  local client = obsidian.new(dir)
  local can_complete, search, insert_start, insert_end = obsidian.completion.can_complete(request)

  if can_complete then
    assert(search ~= nil)
    local items = {}
    for note in client:search(search) do
      for _, alias in pairs(note.aliases) do
        table.insert(items, {
          -- filterText = "[[" .. alias,
          sortText = "[[" .. alias,
          -- insertText = "[[" .. note.id .. "|" .. alias .. "]]",
          label = "[[" .. note.id .. "|" .. alias .. "]]",
          kind = 18,
          textEdit = {
            newText = "[[" .. note.id .. "|" .. alias .. "]]",
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
        })
      end
    end
    return callback {
      items = items,
      isIncomplete = false,
    }
  else
    return callback { isIncomplete = true }
  end
end

source.option = function(_, params)
  return vim.tbl_extend("force", {
    dir = "./",
  }, params.option)
end

return source
