local util = require("obsidian.util")

---@class obsidian.Note
---@field id string
---@field aliases string[]
---@field tags string[]
local note = {}

---Create new note.
---
---@param id string
---@param aliases string[]
---@param tags string[]
---@return obsidian.Note
note.new = function(id, aliases, tags)
  local self = setmetatable({}, { __index = note })
  self.id = id
  self.aliases = aliases and aliases or {}
  self.tags = tags and tags or {}
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

return note
