local PickerName = require("obsidian.config").Picker

local M = {}

--- Get the default Picker.
---
---@param client obsidian.Client
---
---@return obsidian.Picker|?
M.get = function(client)
  local picker_name = client.opts.picker.name
  if picker_name == PickerName.telescope then
    return require("obsidian.pickers._telescope").new(client)
  elseif picker_name == PickerName.mini then
    return require("obsidian.pickers._mini").new(client)
  elseif picker_name == PickerName.fzf_lua then
    return require("obsidian.pickers._fzf").new(client)
  elseif picker_name then
    error("not implemented for " .. picker_name)
  else
    return nil
  end
end

return M
