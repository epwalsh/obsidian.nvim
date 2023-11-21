local Path = require "plenary.path"
local log = require "obsidian.log"

local M = {}

---Substitute Variables inside a given Text
---
---@param text string  - name of a template in the configured templates folder
---@param client obsidian.Client
---@param title string|nil
---@return string
M.substitute_template_variables = function(text, client, title)
  local methods = client.opts.templates.substitutions or {}
  if not methods["date"] then
    methods["date"] = function()
      local date_format = client.opts.templates.date_format or "%Y-%m-%d"
      return tostring(os.date(date_format))
    end
  end
  if not methods["time"] then
    methods["time"] = function()
      local time_format = client.opts.templates.time_format or "%H:%M"
      return tostring(os.date(time_format))
    end
  end
  if title then
    methods["title"] = function()
      return title
    end
  end
  for key, value in pairs(methods) do
    text = string.gsub(text, "{{" .. key .. "}}", value())
  end
  return text
end

---Clone Template
---
---@param template_name string  - name of a template in the configured templates folder
---@param note_path string
---@param client obsidian.Client
---@param title string
M.clone_template = function(template_name, note_path, client, title)
  if client.templates_dir == nil then
    log.err "Templates folder is not defined or does not exist"
    return
  end
  local template_path = Path:new(client.templates_dir) / template_name
  local template_file = io.open(tostring(template_path), "r")
  local note_file = io.open(tostring(note_path), "wb")
  if not template_file then
    return error("Unable to read template at " .. template_path)
  end
  if not note_file then
    return error("Unable to write note at " .. note_path)
  end
  for line in template_file:lines "L" do
    line = M.substitute_template_variables(line, client, title)
    note_file:write(line)
  end
  template_file:close()
  note_file:close()
end

---Insert a template at the given location.
---
---@param name string name of a template in the configured templates folder
---@param client obsidian.Client
---@param location table a tuple with {bufnr, winnr, row, col}
M.insert_template = function(name, client, location)
  if client.templates_dir == nil then
    log.err "Templates folder is not defined or does not exist"
    return
  end
  local buf, win, row, col = unpack(location)
  local template_path = Path:new(client.templates_dir) / name
  local title = require("obsidian.note").from_buffer(buf, client.dir):display_name()

  local insert_lines = {}
  local template_file = io.open(tostring(template_path), "r")
  if template_file then
    local lines = template_file:lines()
    for line in lines do
      line = M.substitute_template_variables(line, client, title)
      table.insert(insert_lines, line)
    end
    template_file:close()
    table.insert(insert_lines, "")
  end

  vim.api.nvim_buf_set_text(buf, row - 1, col, row - 1, col, insert_lines)
  local new_cursor_row, _ = unpack(vim.api.nvim_win_get_cursor(win))
  vim.api.nvim_win_set_cursor(0, { new_cursor_row, 0 })
end

return M
