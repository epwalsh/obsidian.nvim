local completion = require "obsidian.completion"
local obsidian = require "obsidian"
local config = require "obsidian.config"
local util = require "obsidian.util"

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
    for note in client:search(search, "--ignore-case") do
      local aliases = util.unique { note.id, note:display_name(), unpack(note.aliases) }
      for _, alias in pairs(aliases) do
        local options = {}

        local alias_case_matched = util.match_case(search, alias)
        if
          alias_case_matched ~= nil
          and alias_case_matched ~= alias
          and not util.contains(note.aliases, alias_case_matched)
        then
          table.insert(options, alias_case_matched)
        end

        table.insert(options, alias)

        for _, option in pairs(options) do
          local label = "[[" .. note.id
          if option ~= note.id then
            label = label .. "|" .. option .. "]]"
          else
            label = label .. "]]"
          end

          table.insert(items, {
            sortText = "[[" .. option,
            label = label,
            kind = 18,
            textEdit = {
              newText = label,
              range = {
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
