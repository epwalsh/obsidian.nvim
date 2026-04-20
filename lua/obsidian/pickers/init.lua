local PickerName = require("obsidian.config").Picker

local M = {}

--- Get the default Picker.
---
---@param client obsidian.Client
---@param picker_name obsidian.config.Picker|?
---
---@return obsidian.Picker|?
M.get = function(client, picker_name)
  picker_name = picker_name and picker_name or client.opts.picker.name
  if picker_name then
    picker_name = string.lower(picker_name)
  else
    for _, name in ipairs { PickerName.telescope, PickerName.fzf_lua, PickerName.mini, PickerName.snacks } do
      local ok, res = pcall(M.get, client, name)
      if ok then
        return res
      end
    end
    return nil
  end

  if picker_name == string.lower(PickerName.telescope) then
    return require("obsidian.pickers._telescope").new(client)
  elseif picker_name == string.lower(PickerName.mini) then
    return require("obsidian.pickers._mini").new(client)
  elseif picker_name == string.lower(PickerName.fzf_lua) then
    return require("obsidian.pickers._fzf").new(client)
  elseif picker_name == string.lower(PickerName.snacks) then
    return require("obsidian.pickers._snacks").new(client)
  elseif picker_name then
    error("not implemented for " .. picker_name)
  end
end

return M
