local M = {}

---Generates the completion request from a blink context
---@param context blink.cmp.Context
---@return obsidian.completion.sources.base.Request
M.generate_completion_request_from_editor_state = function(context)
  local row = context.cursor[1]
  local col = context.cursor[2]
  local cursor_before_line = context.line:sub(1, col)
  local cursor_after_line = context.line:sub(col + 1)

  return {
    context = {
      bufnr = context.bufnr,
      cursor_before_line = cursor_before_line,
      cursor_after_line = cursor_after_line,
      cursor = {
        row = row,
        col = col,
        line = row + 1,
      },
    },
  }
end

M.incomplete_response = {
  is_incomplete_forward = true,
  is_incomplete_backward = true,
  items = {},
}

M.complete_response = {
  is_incomplete_forward = true,
  is_incomplete_backward = false,
  items = {},
}

return M
