local source = {}

source.new = function()
  return setmetatable({}, { __index = source })
end

source.get_trigger_characters = function()
  return { "[" }
end

source.complete = function(self, request, callback)
  local client = self:option(request).client
  if client == nil then
    error("Obsidian completion has not been setup correctly!")
  end

  local input = string.sub(request.context.cursor_before_line, request.offset - 2)
  local suffix = string.sub(request.context.cursor_after_line, 1, 2)

  if vim.startswith(input, "[[") and suffix == "]]" then
    local items = {}
    table.insert(items, {
      filterText = "foo",
      label = "[[foo]]",
      kind = 18,
      textEdit = {
        newText = "[[foo]]",
        range = {
          start = {
            line = request.context.cursor.row - 1,
            character = request.context.cursor.col - 1 - #input,
          },
          ["end"] = {
            line = request.context.cursor.row - 1,
            character = request.context.cursor.col + 1,
          },
        },
      },
    })
    callback {
      items = items,
      isIncomplete = true,
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
