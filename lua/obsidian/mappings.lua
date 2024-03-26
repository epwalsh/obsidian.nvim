local util = require "obsidian.util"

local M = {}

---@class obsidian.mappings.MappingConfig
---@field action function
---@field opts table

---@return obsidian.mappings.MappingConfig
M.smart_action = function()
  return { action = util.smart_action, opts = { noremap = false, expr = true, buffer = true } }
end

M.gf_passthrough = function()
  return { action = util.gf_passthrough, opts = { noremap = false, expr = true, buffer = true } }
end

M.toggle_checkbox = function()
  return { action = util.toggle_checkbox, opts = { buffer = true, desc = "Toggle Checkbox" } }
end

return M
