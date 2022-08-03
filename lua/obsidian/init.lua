local Pathlib = require "plenary.path"

local obsidian = {}

obsidian.note = require "obsidian.note"
obsidian.cache = require "obsidian.cache"
obsidian.util = require "obsidian.util"

---@class obsidian.Client
---@field dir Path
---@field cache obsidian.Cache
local client = {}

---Setup a new Obsidian client.
---
---@param params table
---@return obsidian.Client
obsidian.setup = function(params)
  local self = setmetatable({}, { __index = client })

  self.dir = Pathlib:new(vim.fs.normalize(params.dir and params.dir or "./"))
  self.cache = obsidian.cache.new(self.dir)

  -- Ensure directory exists.
  self.dir:mkdir { parents = true, exits_ok = true }

  return self
end

---Load cache.
---
---@param refresh boolean|?
client.load_cache = function(self, refresh)
  if refresh then
    self.cache:clear()
  end
  for _, fname in pairs(obsidian.util.find_markdown_files(self.dir)) do
    local path = Pathlib:new(fname)
    if path:is_file() then
      local note = obsidian.note.from_file(path)
      self.cache:set(note)
    end
  end
end

return obsidian
