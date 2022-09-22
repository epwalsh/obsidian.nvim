local completion = require "obsidian.completion"
local obsidian = require "obsidian"
local config = require "obsidian.config"

local source = {}

source.new = function()
  return setmetatable({}, { __index = source })
end

source.get_trigger_characters = completion.get_trigger_characters

source.get_keyword_pattern = completion.get_keyword_pattern

source.complete = function(self, request, callback)
  local opts = self:option(request)
  local client = obsidian.new(opts)
  local can_complete, search, insert_start, insert_end = completion.can_complete(request)

  if can_complete and search ~= nil and #search >= opts.completion.min_chars then
    local items = {}
    for note in client:search(search) do
      for _, alias in pairs(note.aliases) do
        table.insert(items, {
          sortText = "[[" .. alias,
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

---Get opts.
---
---@return obsidian.config.ClientOpts
source.option = function(_, params)
  return config.ClientOpts.normalize(params.option)
end

return source
