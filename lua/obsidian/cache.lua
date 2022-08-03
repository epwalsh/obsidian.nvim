local sqlite = require("sqlite.db")
local util = require("obsidian.util")

---@class CacheDatabase: sqlite_db
---@field notes sqlite_tbl
---@field aliases sqlite_tbl
---@field tags sqlite_tbl

---@class obsidian.Cache
---@field db CacheDatabase
local cache = {}

---Initialize a new cache.
---
---@param dir string
cache.new = function(dir)
  local self = setmetatable({}, { __index = cache })

  -- Setup cache database.
  self.db = sqlite {
    uri = dir .. "/.obsidian_db",
    notes = {
      id = { "text", required = true, unique = true, primary = true },
      aliases = "luatable",
      tags = "luatable",
    },
    aliases = {
      id = true,
      name = { "text", required = true },
      note = { "text", required = true, reference = "notes.id", on_delete = "cascade" },
    },
    tags = {
      id = true,
      name = { "text", required = true },
      note = { "text", required = true, reference = "notes.id", on_delete = "cascade" },
    },
  }

  -- Create indices on 'aliases' and 'tags' for fast glob searches.
  self.db:with_open(function()
    self.db:eval("CREATE INDEX IF NOT EXISTS aliases_idx ON aliases (name)")
    self.db:eval("CREATE INDEX IF NOT EXISTS tags_idx ON tags (name)")
  end)

  return self
end

---Check if the cache contains a note.
---
---@param id string
---@return boolean
cache.contains = function(self, id)
  local entries = self.db.notes:get {
    where = { id = id },
    select = { "id" },
  }
  if #entries > 0 then
    return true
  else
    return false
  end
end

---Get all cached aliases.
---
---@param id string
---@return string[]
cache.cached_aliases = function(self, id)
  return self.db.aliases:get {
    where = { note = id },
    select = { "name" },
  }
end

---Get all cached tags.
---
---@param id string
---@return string[]
cache.cached_tags = function(self, id)
  return self.db.tags:get {
    where = { note = id },
    select = { "name" },
  }
end

---Get a note from the cache.
---
---@param id string
---@return obsidian.Note
cache.get = function(self, id)
  local entries = self.db.notes:get {
    where = { id = id },
    select = { "id", "aliases", "tags" }
  }
  if #entries > 0 then
    return entries[1]
  else
    error("Key error '" .. id .. "'")
  end
end

---Convert cached entries from database into note objects.
---
---@return obsidian.Note[]
cache._notes_from_search_entries = function(self, entries)
  local out = {}
  local found = {}
  for _, entry in pairs(entries) do
    if found[entry.note] == nil then
      found[entry.note] = true
      table.insert(out, self:get(entry.note))
    end
  end
  return out
end

---Search for cached notes by alias.
---
---@return obsidian.Note[]
cache.search_alias = function(self, alias)
  local entries = self.db.aliases:get {
    contains = { name = alias .. "*" },
    select = { "name", "note" },
  }
  return self:_notes_from_search_entries(entries)
end

---Search for cached notes by tags.
---
---@return obsidian.Note[]
cache.search_tag = function(self, tag)
  local entries = self.db.tags:get {
    contains = { name = tag .. "*" },
    select = { "name", "note" },
  }
  return self:_notes_from_search_entries(entries)
end

---Add or update a note in the cache.
---
---@param note obsidian.Note
cache.set = function(self, note)
  if self:contains(note.id) then
    -- Update existing note.
    self.db.notes:update({
      where = { id = note.id },
      set = { aliases = note.aliases, tags = note.tags },
    })

    -- Remove aliases that are no longer tied to the note.
    local cached_aliases = self:cached_aliases(note.id)
    for _, alias in pairs(cached_aliases) do
      if not note:has_alias(alias) then
        self.db.aliases:remove({ name = alias, note = note.id })
      end
    end

    -- Insert new aliases.
    for _, alias in pairs(note.aliases) do
      if not util.contains(cached_aliases, alias) then
        self.db.aliases:insert({ name = alias, note = note.id })
      end
    end

    -- Remove tags that are no longer tied to the note.
    local cached_tags = self:cached_tags(note.id)
    for _, tag in pairs(cached_tags) do
      if not note:has_tag(tag) then
        self.db.tags:remove({ name = tag, note = note.id })
      end
    end

    -- Insert new tags.
    for _, tag in pairs(note.tags) do
      if not util.contains(cached_tags, tag) then
        self.db.tags:insert({ name = tag, note = note.id })
      end
    end

  else
    -- Insert new note.
    self.db.notes:insert(note)

    -- Insert aliases.
    for _, alias in pairs(note.aliases) do
      self.db.aliases:insert({ name = alias, note = note.id })
    end

    -- Insert tags.
    for _, tag in pairs(note.tags) do
      self.db.tags:insert({ name = tag, note = note.id })
    end
  end
end

---Remove a note from the cache.
---
---@param id string
cache.remove = function(self, id)
  self.db.notes:remove({ id = id })
  self.db.aliases:remove({ note = id })
  self.db.tags:remove({ note = id })
end

---Clear the cache.
cache.clear = function(self)
  self.db.notes:remove(nil)
  self.db.aliases:remove(nil)
  self.db.tags:remove(nil)
end

---Get the size of the cache.
---
---@return number
cache.size = function(self)
  return self.db.notes:count()
end

return cache
