local Pathlib = require('plenary.path')
local util = require("obsidian.util")
local yaml = require("deps.lua_yaml.yaml")

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

---Initialize a note from a file.
---
---@param path string|Path
---@return obsidian.Note
note.from_file = function(path)
  local frontmatter_lines, _ = note.frontmatter(path)
  local frontmatter = table.concat(frontmatter_lines, "\n")
  local data = yaml.eval(frontmatter)
  return note.new(data.id, data.aliases, data.tags, path)
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

---Get the frontmatter lines.
---
---@param path string|Path
---@return string[]
---@return integer
note.frontmatter = function(path)
  if path == nil then
    error("note path cannot be nil")
  end
  local f = io.open(tostring(path))
  if f == nil then
    error("failed to read file")
  end

  local lines = {}
  local in_frontmatter, start_idx = false, 0
  for line in f:lines() do
    if not in_frontmatter then
      start_idx = start_idx + 1
      if line:match("^---$") then
        in_frontmatter = true
      end
    elseif line:match("^---$") then
      f:close()
      return lines, start_idx
    else
      table.insert(lines, line)
    end
  end
  error("Failed to parse frontmatter")
end

---Save note to file.
---
---@param path string|Path|?
note.save = function(self, path)
  if self.path == nil then
    error("note path cannot be nil")
  end
  local self_f = io.open(tostring(self.path))
  if self_f == nil then
    error("failed to read file")
  end

  --Read lines.
  local lines = {}
  local in_frontmatter, frontmatter_done, start_idx, end_idx = false, false, 0, 0
  local contents = self_f:read("*a")
  for _, line in pairs(vim.split(contents, "\n")) do
    table.insert(lines, line .. "\n")
    if not frontmatter_done then
      if not in_frontmatter then
        start_idx = start_idx + 1
        end_idx = end_idx + 1
        if line:match("^---$") then
          in_frontmatter = true
        end
      elseif line:match("^---$") then
        end_idx = end_idx + 1
        frontmatter_done = true
      else
        end_idx = end_idx + 1
      end
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

  -- Add remaining original lines.
  for i = end_idx + 1, #lines do
    table.insert(new_lines, lines[i])
  end

  --Write new lines.
  local save_path = path and path or self.path
  assert(save_path ~= nil)
  local save_f = io.open(tostring(save_path), "w")
  if save_f == nil then
    error("failed to write file")
  end
  for _, line in pairs(new_lines) do
    save_f:write(line)
  end
  save_f:close()

  return lines
end

return note
