local obsidian = {}

obsidian.note = require("obsidian.note")
obsidian.cache = require("obsidian.cache")

---@class obsidian.Client
---@field dir string
---@field cache obsidian.Cache
local client

---Setup a new Obsidian client.
---
---@param params table
---@return obsidian.Client
obsidian.setup = function(params)
  local self = setmetatable({}, { __index = client })
  self.dir = params.dir and params.dir or "./"
  self.cache = obsidian.cache.new(self.dir)
  return self
end

return obsidian
