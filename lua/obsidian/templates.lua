local Path = require "obsidian.path"
local Note = require "obsidian.note"
local util = require "obsidian.util"
local iter = require("obsidian.itertools").iter
local compat = require "obsidian.compat"
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

  -- Replace known variables.
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

  -- Find unknown variables and prompt for them.
  for m_start, m_end in util.gfind(text, "{{[^}]+}}") do
    local key = util.strip_whitespace(string.sub(text, m_start + 2, m_end - 2))
    local value = util.input(string.format("Enter value for '%s' (<cr> to skip): ", key))
    if value and string.len(value) > 0 then
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

  local template_file, read_err = io.open(tostring(template_path), "r")
  if not template_file then
    error(string.format("Unable to read template at '%s': %s", template_path, tostring(read_err)))
  end

  local note_file, write_err = io.open(tostring(note_path), "w")
  if not note_file then
    error(string.format("Unable to write note at '%s': %s", note_path, tostring(write_err)))
  end

  for line in template_file:lines "L" do
    line = M.substitute_template_variables(line, opts.client, opts.note)
    note_file:write(line)
  end

  assert(template_file:close())
  assert(note_file:close())

  local new_note = Note.from_file(note_path)

  -- Transfer fields from `opts.note`.
  new_note.id = opts.note.id
  if new_note.title == nil then
    new_note.title = opts.note.title
  end
  for _, alias in ipairs(opts.note.aliases) do
    new_note:add_alias(alias)
  end
  for _, tag in ipairs(opts.note.tags) do
    new_note:add_tag(tag)
  end

  return new_note
end

--- Reads line from line_iterator and appends the frontmatter to the passed note
--- Returns remaining content of the line_iterator and the size of frontmatter
---@param line_iterator fun(): string?
---@param buf integer -- buffer id of the opened buffer
---@param opts { template_name: string|obsidian.Path, client: obsidian.Client, location: { [1]: integer, [2]: integer, [3]: integer, [4]: integer } } Options.
---@return integer -- Total lines of frontmatter
---@return table -- Remaining content of passed iterator excluding frontmatter
---

local merge_frontmatter = function(line_iterator, buf, opts)
  local data = {}
  local note = Note.from_buffer(buf)
  local frontmatter_end = 0
  local manage_frontmatter = opts.client:should_save_frontmatter(note)
  local content_start
  local in_frontmatter, has_frontmatter, first_line = false, false, true
  for line in line_iterator do
    if line == "---" then
      if first_line then
        first_line = false
        in_frontmatter = true
      else
        has_frontmatter = true
        in_frontmatter = false
        frontmatter_end = frontmatter_end + 1
      end
    end
    local new_line = M.substitute_template_variables(line, opts.client, note)
    data[#data + 1] = new_line
    if in_frontmatter then
      frontmatter_end = frontmatter_end + 1
    elseif content_start == nil then
      content_start = frontmatter_end + 1
    end
  end
  if manage_frontmatter then
    if has_frontmatter == false and frontmatter_end > 0 then
      error "Template has invalid frontmatter!"
    end
    local template_as_note = Note.from_lines(iter { unpack(data, 1, frontmatter_end) }, note.path, opts)
    if not note.metadata then
      note.metadata = {}
    end
    for key in iter(template_as_note.metadata) do
      note.metadata[key] = template_as_note[key]
    end
    for key in iter(template_as_note.tags) do
      note:add_tag(key)
    end
    local insert_lines = compat.flatten(note:frontmatter_lines(false))
    if has_frontmatter then
      vim.api.nvim_buf_set_lines(buf, 0, frontmatter_end, false, {})
    end
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, insert_lines)
    return content_start, { unpack(data, content_start, #data) }
  else
    return nil, data
  end
end

---Insert a template at the given location.
---
---@param opts { template_name: string|obsidian.Path, client: obsidian.Client, location: { [1]: integer, [2]: integer, [3]: integer, [4]: integer } } Options.
---
---@return obsidian.Note
M.insert_template = function(opts)
  local buf, win, row, _ = unpack(opts.location)
  local template_path = resolve_template(opts.template_name, opts.client)
  local insert_lines = {}
  local template_file = io.open(tostring(template_path), "r")
  if template_file then
    local lines = template_file:lines()
    local content_start, data = merge_frontmatter(lines, buf, opts)
    row = content_start or row - 1
    for line in iter(data) do
      if string.find(line, "[\r\n]") then
        local line_start = 1
        for line_end in util.gfind(line, "[\r\n]") do
          local new_line = string.sub(line, line_start, line_end - 1)
          table.insert(insert_lines, new_line)
          line_start = line_end + 1
        end
        local last_line = string.sub(line, line_start)
        if string.len(last_line) > 0 then
          table.insert(insert_lines, last_line)
        end
      else
        table.insert(insert_lines, line)
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
