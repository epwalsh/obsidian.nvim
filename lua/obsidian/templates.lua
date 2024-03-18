local Path = require "obsidian.path"
local Note = require "obsidian.note"
local util = require "obsidian.util"

local M = {}

--- Resolve a template name to a path.
---
---@param template_name string|obsidian.Path
---@param client obsidian.Client
---
---@return obsidian.Path
local resolve_template = function(template_name, client)
  local templates_dir = client:templates_dir()
  if templates_dir == nil then
    error "Templates folder is not defined or does not exist"
  end

  ---@type obsidian.Path|?
  local template_path
  local paths_to_check = { templates_dir / tostring(template_name), Path:new(template_name) }
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
    error(string.format("Template '%s' not found", template_name))
  end

  return template_path
end

--- Substitute variables inside the given text.
---
---@param text string
---@param client obsidian.Client
---@param note obsidian.Note
---
---@return string
M.substitute_template_variables = function(text, client, note)
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

  if not methods["title"] then
    methods["title"] = note.title or note:display_name()
  end

  if not methods["id"] then
    methods["id"] = tostring(note.id)
  end

  if not methods["path"] and note.path then
    methods["path"] = tostring(note.path)
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

--- Clone template to a new note.
---
---@param opts { template_name: string|obsidian.Path, path: obsidian.Path|string, client: obsidian.Client, note: obsidian.Note } Options.
---
---@return obsidian.Note
M.clone_template = function(opts)
  local note_path = Path.new(opts.path)
  assert(note_path:parent()):mkdir { parents = true, exist_ok = true }

  local template_path = resolve_template(opts.template_name, opts.client)
  local template_file = io.open(tostring(template_path), "r")
  if not template_file then
    error(string.format("Unable to read template at '%s'", template_path))
  end

  local note_file = io.open(tostring(note_path), "wb")
  if not note_file then
    error(string.format("Unable to write note at '%s'", note_path))
  end

  for line in template_file:lines "L" do
    note_file:write(M.substitute_template_variables(line, opts.client, opts.note))
  end

  template_file:close()
  note_file:close()

  return Note.from_file(note_path)
end

---Insert a template at the given location.
---
---@param opts { template_name: string|obsidian.Path, client: obsidian.Client, location: { [1]: integer, [2]: integer, [3]: integer, [4]: integer } } Options.
---
---@return obsidian.Note
M.insert_template = function(opts)
  local buf, win, row, _ = unpack(opts.location)
  local note = Note.from_buffer(buf)

  local template_path = resolve_template(opts.template_name, opts.client)

  local insert_lines = {}
  local template_file = io.open(tostring(template_path), "r")
  if template_file then
    local lines = template_file:lines()
    for line in lines do
      local new_lines = M.substitute_template_variables(line, opts.client, note)
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
    error(string.format("Template file '%s' not found", template_path))
  end

  vim.api.nvim_buf_set_lines(buf, row, row, false, insert_lines)
  local new_cursor_row, _ = unpack(vim.api.nvim_win_get_cursor(win))
  vim.api.nvim_win_set_cursor(0, { new_cursor_row, 0 })

  opts.client:update_ui(0)

  return Note.from_buffer(buf)
end

return M
