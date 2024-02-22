local Path = require "plenary.path"
local log = require "obsidian.log"
local util = require "obsidian.util"

local M = {}

---Substitute Variables inside a given Text
---
---@param text string  - name of a template in the configured templates folder
---@param client obsidian.Client
---@param title string|nil
---@return string
M.substitute_template_variables = function(text, client, title)
  local methods = vim.deepcopy(client.opts.templates.substitutions or {})

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
    methods["title"] = title
  end

  for key, subst in pairs(methods) do
    for m_start, m_end in util.gfind(text, "{{" .. key .. "}}", nil, true) do
      ---@type string
      local value
      if type(subst) == "string" then
        value = subst
      else
        value = subst()
        -- cache the result
        methods[key] = value
      end
      text = string.sub(text, 1, m_start - 1) .. value .. string.sub(text, m_end + 1)
    end
  end

  return text
end

---Clone Template
---
---@param template_name string  - name of a template in the configured templates folder
---@param note_path Path
---@param client obsidian.Client
---@param title string
M.clone_template = function(template_name, note_path, client, title)
  local templates_dir = client:templates_dir()
  if templates_dir == nil then
    log.err "Templates folder is not defined or does not exist"
    return
  end

  util.parent_directory(note_path):mkdir { parents = true }

  local template_path = Path:new(templates_dir) / template_name
  local template_file = io.open(tostring(template_path), "r")
  if not template_file then
    return log.error("Unable to read template at '%s'", template_path)
  end

  local note_file = io.open(tostring(note_path), "wb")
  if not note_file then
    return log.error("Unable to write note at '%s'", note_path)
  end

  for line in template_file:lines "L" do
    note_file:write(M.substitute_template_variables(line, client, title))
  end

  template_file:close()
  note_file:close()
end

---Insert a template at the given location.
---
---@param name string name or path of a template in the configured templates folder
---@param client obsidian.Client
---@param location table a tuple with {bufnr, winnr, row, col}
M.insert_template = function(name, client, location)
  local templates_dir = client:templates_dir()
  if templates_dir == nil then
    log.err "Templates folder is not defined or does not exist"
    return
  end
  local buf, win, row, _ = unpack(location)
  local title = require("obsidian.note").from_buffer(buf, client.dir):display_name()

  ---@type Path
  local template_path
  local paths_to_check = { templates_dir / name, Path:new(name) }
  for _, path in ipairs(paths_to_check) do
    if path:is_file() then
      template_path = path
      break
    elseif not vim.endswith(tostring(path), ".md") then
      local path_with_suffix = Path:new(tostring(path) .. ".md")
      if path_with_suffix:is_file() then
        template_path = path_with_suffix
        break
      end
    end
  end

  if template_path == nil then
    log.err("Template '%s' not found", name)
    return
  end

  local insert_lines = {}
  local template_file = io.open(tostring(template_path), "r")
  if template_file then
    local lines = template_file:lines()
    for line in lines do
      local new_lines = M.substitute_template_variables(line, client, title)
      if string.find(new_lines, "[\r\n]") then
        local line_start = 1
        for line_end in util.gfind(new_lines, "[\r\n]") do
          local new_line = string.sub(new_lines, line_start, line_end - 1)
          table.insert(insert_lines, new_line)
          line_start = line_end + 1
        end
        local last_line = string.sub(new_lines, line_start)
        if string.len(last_line) > 0 then
          table.insert(insert_lines, last_line)
        end
      else
        table.insert(insert_lines, new_lines)
      end
    end
    template_file:close()
  else
    log.err("Template file '%s' not found", template_path)
    return
  end

  vim.api.nvim_buf_set_lines(buf, row, row, false, insert_lines)
  local new_cursor_row, _ = unpack(vim.api.nvim_win_get_cursor(win))
  vim.api.nvim_win_set_cursor(0, { new_cursor_row, 0 })

  client:update_ui(0)
end

return M
