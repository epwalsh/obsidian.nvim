local mapping = {}

---@class obsidian.mapping.MappingConfig
---@field action function
---@field opts table

---@return obsidian.mapping.MappingConfig
mapping.gf_passthrough = function()
  return { action = require("obsidian").util.gf_passthrough, opts = { noremap = false, expr = true, buffer = true } }
end

return mapping
