local M = {}

--- Helper to map custom telescope actions.
--- Used by different commands.
---@param client obsidian.Client
---@param initial_query string|?
M.telescope_mappings = function(map, client, initial_query)
  -- Docs for telescope actions:
  -- https://github.com/nvim-telescope/telescope.nvim/blob/master/lua/telescope/actions/init.lua
  local telescope_actions = require("telescope.actions.mt").transform_mod {
    obsidian_new = function(prompt_bufnr)
      local query = require("telescope.actions.state").get_current_line()
      if not query or string.len(query) == 0 then
        query = initial_query
      end
      require("telescope.actions").close(prompt_bufnr)
      client:command("ObsidianNew", { args = query })
    end,

    obsidian_insert_link = function(prompt_bufnr)
      local selected_path = require("telescope.actions.state").get_selected_entry().path
      local vault_relative_path = client:vault_relative_path(selected_path)
      require("telescope.actions").close(prompt_bufnr)
      vim.api.nvim_put({ "[](" .. vault_relative_path .. ")" }, "", false, true)
    end,
  }

  local new_mapping = client.opts.finder_mappings.new
  if new_mapping ~= nil then
    map({ "i", "n" }, new_mapping, telescope_actions.obsidian_new)
  end

  local insert_link_mapping = client.opts.finder_mappings.insert_link
  if insert_link_mapping ~= nil then
    map({ "i", "n" }, insert_link_mapping, telescope_actions.obsidian_insert_link)
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
  keys = client.opts.finder_mappings.insert_link
  if keys ~= nil then
    prompt_title = prompt_title .. " | " .. keys .. " insert link"
  end
  return prompt_title
end

--- With certain versions of fzf and fzf-lua, fzf-lua passes the selection
--- with some odd unicode characters as a prefix.
---
---@param entry string
---
---@return string
M.fzf_lua_clean_selection = function(entry)
  if vim.startswith(entry, "M") then
    entry = entry:sub(5)
  elseif vim.startswith(entry, "  ") then
    -- these two whitespace-looking characters are actual 6 chars in length.
    entry = string.sub(entry, 7)
  end
  return entry
end

return M
