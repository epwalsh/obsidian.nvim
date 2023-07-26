local mapping = {}

---@class obsidian.mapping.MappingConfig
---@field action function
---@field opts table

---@return obsidian.mapping.MappingConfig
mapping.gf_passthrough = function()
  local action = function()
    if require("obsidian").util.cursor_on_markdown_link() then
      return "<cmd>ObsidianFollowLink<CR>"
    else
      return "gf"
    end
  end

  local opts = { noremap = false, expr = true, buffer = true }
  return { action = action, opts = opts }
end

return mapping
