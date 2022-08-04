local Pathlib = require "plenary.path"
local util = require "obsidian.util"
local yaml = require "deps.lua_yaml.yaml"

---@class obsidian.Note
---@field id string
---@field aliases string[]
---@field tags string[]
---@field path Path|?
local note = {}

---Create new note.
---
---@param id string
---@param aliases string[]
---@param tags string[]
---@param path string|Path|?
---@return obsidian.Note
note.new = function(id, aliases, tags, path)
  local self = setmetatable({}, { __index = note })
  self.id = id
  self.aliases = aliases and aliases or {}
  self.tags = tags and tags or {}
  self.path = path and Pathlib:new(path) or nil
  return self
end

---Check if a note has a given alias.
---
---@param alias string
---@return boolean
note.has_alias = function(self, alias)
  return util.contains(self.aliases, alias)
end

---Check if a note has a given tag.
---
---@param tag string
---@return boolean
note.has_tag = function(self, tag)
  return util.contains(self.tags, tag)
end

---Add an alias to the note.
---
---@param alias string
note.add_alias = function(self, alias)
  if not self:has_alias(alias) then
    table.insert(self.aliases, alias)
  end
end

---Add a tag to the note.
---
---@param tag string
note.add_tag = function(self, tag)
  if not self:has_tag(tag) then
    table.insert(self.tags, tag)
  end
end

---Initialize a note from a file.
---
---@param path string|Path
---@param root string|Path|?
---@return obsidian.Note
note.from_file = function(path, root)
  if path == nil then
    error "note path cannot be nil"
  end
  local f = io.open(vim.fs.normalize(tostring(path)))
  if f == nil then
    error "failed to read file"
  end

  local cwd = tostring(root and root or "./")
  local relative_path = tostring(Pathlib:new(path):make_relative(cwd))

  local id = nil
  local title = nil
  local aliases = {}
  local tags = {}

  -- Iterate over lines in the file, collecting frontmatter and parsing the title.
  local frontmatter_lines = {}
  local has_frontmatter, in_frontmatter = false, false
  local line_idx = 0
  for line in f:lines() do
    line_idx = line_idx + 1
    if line_idx == 1 then
      if note._is_frontmatter_boundary(line) then
        has_frontmatter = true
        in_frontmatter = true
      else
        local maybe_title = note._parse_header(line)
        if maybe_title then
          title = maybe_title
          break
        end
      end
    elseif has_frontmatter and in_frontmatter then
      if note._is_frontmatter_boundary(line) then
        in_frontmatter = false
      else
        table.insert(frontmatter_lines, line)
      end
    else
      local maybe_title = note._parse_header(line)
      if maybe_title then
        title = maybe_title
        break
      end
    end
  end

  -- Parse the frontmatter YAML.
  if #frontmatter_lines > 0 then
    local frontmatter = table.concat(frontmatter_lines, "\n")
    local ok, data = pcall(yaml.eval, frontmatter)
    if ok then
      if data.id then
        id = data.id
      end
      if data.aliases then
        aliases = data.aliases
      end
      if data.tags then
        tags = data.tags
      end
    end
  end

  -- Use title as an alias.
  if title ~= nil and not util.contains(aliases, title) then
    table.insert(aliases, title)
  end

  -- Fall back to using the relative path as the ID.
  if id == nil then
    id = relative_path
  end

  return note.new(id, aliases, tags, path)
end

---Check if a line matches a frontmatter boundary.
---
---@param line string
---@return boolean
note._is_frontmatter_boundary = function(line)
  return line:match "^---+$" ~= nil
end

---Try parsing a header from a line.
---
---@param line string
---@return string|?
note._parse_header = function(line)
  return line:match "^#+ (.+)$"
end

---Save note to file.
---
---@param path string|Path|?
note.save = function(self, path)
  if self.path == nil then
    error "note path cannot be nil"
  end
  local self_f = io.open(tostring(self.path))
  if self_f == nil then
    error "failed to read file"
  end

  -- Read lines.
  local lines = {}
  local has_frontmatter, in_frontmatter = false, false
  local end_idx = 0
  local contents = self_f:read "*a"
  for idx, line in pairs(vim.split(contents, "\n")) do
    table.insert(lines, line .. "\n")
    if idx == 1 then
      if note._is_frontmatter_boundary(line) then
        has_frontmatter = true
        in_frontmatter = true
      end
    elseif has_frontmatter and in_frontmatter then
      if note._is_frontmatter_boundary(line) then
        end_idx = idx
        in_frontmatter = false
      end
    else
      break
    end
  end
  self_f:close()

  -- Replace frontmatter.
  local new_lines = { "---\n", "id: " .. self.id .. "\n" }

  if #self.aliases > 0 then
    table.insert(new_lines, "aliases:\n")
  else
    table.insert(new_lines, "aliases: []\n")
  end
  for _, alias in pairs(self.aliases) do
    table.insert(new_lines, " - " .. alias .. "\n")
  end

  if #self.tags > 0 then
    table.insert(new_lines, "tags:\n")
  else
    table.insert(new_lines, "tags: []\n")
  end
  for _, tag in pairs(self.tags) do
    table.insert(new_lines, " - " .. tag .. "\n")
  end

  table.insert(new_lines, "---\n")
  if not has_frontmatter then
    -- Make sure there's an empty line between end of the frontmatter and the contents.
    table.insert(new_lines, "\n")
  end

  -- Add remaining original lines.
  for i = end_idx + 1, #lines do
    table.insert(new_lines, lines[i])
  end

  --Write new lines.
  local save_path = path and path or self.path
  assert(save_path ~= nil)
  local save_f = io.open(tostring(save_path), "w")
  if save_f == nil then
    error "failed to write file"
  end
  for _, line in pairs(new_lines) do
    save_f:write(line)
  end
  save_f:close()

  return lines
end

return note
