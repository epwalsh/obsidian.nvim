local set_checkbox = require("obsidian.util").set_checkbox

---@param client obsidian.Client
return function(client, data)
  set_checkbox(data.args)
end
