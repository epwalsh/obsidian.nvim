local toggle_checkbox = require("obsidian.util").toggle_checkbox

---@param client obsidian.Client
return function(client)
  local checkboxes = vim.tbl_keys(client.opts.ui.checkboxes)
  table.sort(checkboxes, function(a, b)
    return (client.opts.ui.checkboxes[a].order or 1000) < (client.opts.ui.checkboxes[b].order or 1000)
  end)
  toggle_checkbox(checkboxes)
end
