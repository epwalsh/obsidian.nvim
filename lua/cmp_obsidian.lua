local source = {}

source.new = function()
  return setmetatable({}, { __index = source })
end

source.get_trigger_characters = function()
  return { "[" }
end

source.get_keyword_pattern = function()
  -- See ':help pattern'
  -- Note that the enclosing [=[ ... ]=] is just a way to mark the boundary of a
  -- string in Lua.
  return [=[\%(\s\|^\)\zs\[\{2}[^\]]\+\]\{,2}]=]
end

---Backtrack through a string to find the first occurence of '[['.
---@param input string
---@return string
source._find_search_start = function(input)
  for i = string.len(input) - 1, 1, -1 do
    local substr = string.sub(input, i)
    if vim.startswith(substr, "[[") then
      return substr
    end
  end
  return input
end

source.complete = function(self, request, callback)
  local dir = self:option(request).dir
  if dir == nil then
    error "Obsidian completion has not been setup correctly!"
  end
  local client = require("obsidian").new(dir)

  local input = source._find_search_start(request.context.cursor_before_line)
  local suffix = string.sub(request.context.cursor_after_line, 1, 2)
  local search = string.sub(input, 3)
  print("Input:", input)

  if string.len(search) > 0 and vim.startswith(input, "[[") then
    local insert_end_offset = suffix == "]]" and 1 or -1
    local items = {}
    for _, note in pairs(client:search(search)) do
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
                character = request.context.cursor.col - 1 - #input,
              },
              ["end"] = {
                line = request.context.cursor.row - 1,
                character = request.context.cursor.col + insert_end_offset,
              },
            },
          },
        })
      end
    end
    callback {
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
