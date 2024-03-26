local toggle_checkbox = require("obsidian.util").toggle_checkbox

---@param client obsidian.Client
return function(client)
  local checkboxes = vim.tbl_keys(client.opts.ui.checkboxes)
  for k, v in pairs(client.opts.ui.checkboxes) do
    local order = v.order
    if order and type(order) == "number" then
      -- sort the checkboxes based on order
      checkboxes[order] = k
    end
  end
  toggle_checkbox(checkboxes)
end
