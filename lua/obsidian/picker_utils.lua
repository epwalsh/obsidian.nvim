local M = {}

--- Helper to map custom telescope actions.
--- Used by different commands.
---@param client obsidian.Client
M.telescope_mappings = function(map, client)
  -- Docs for telescope actions:
  -- https://github.com/nvim-telescope/telescope.nvim/blob/master/lua/telescope/actions/init.lua
  local telescope_actions = require("telescope.actions.mt").transform_mod {
    obsidian_new = function(prompt_bufnr)
      local query = require("telescope.actions.state").get_current_line()
      require("telescope.actions").close(prompt_bufnr)
      client:command("ObsidianNew", { args = query })
    end,
  }

  local new_mapping = client.opts.finder_mappings.new
  if new_mapping ~= nil then
    map({ "i", "n" }, new_mapping, telescope_actions.obsidian_new)
  end
  return true
end

--- Helper to create a prompt title for telescope.
--- Used by different commands.
---@param name string
---@param client obsidian.Client
M.telescope_prompt_title = function(name, client)
  local prompt_title = name .. " | <CR> open"
  local keys = client.opts.finder_mappings.new
  if keys ~= nil then
    prompt_title = prompt_title .. " | " .. keys .. " new"
  end
  return prompt_title
end

return M
