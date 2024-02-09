local search = require "obsidian.search"
local Picker = require("obsidian.config").Picker

---@param client obsidian.Client
return function(client, _)
  local dir = tostring(client.dir)
  local search_opts =
    search.SearchOpts.from_tbl { sort_by = client.opts.sort_by, sort_reversed = client.opts.sort_reversed }

  client:_run_with_picker_backend {
    [Picker.telescope] = function()
      local has_telescope, telescope = pcall(require, "telescope.builtin")
      if not has_telescope then
        return false
      end

      local picker_utils = require "obsidian.picker_utils"
      telescope.find_files {
        prompt_title = picker_utils.telescope_prompt_title("ObsidianQuickSwitch", client),
        cwd = dir,
        search_file = "*.md",
        find_command = search.build_find_cmd(".", nil, search_opts),
        attach_mappings = function(_, map)
          return picker_utils.telescope_mappings(map, client)
        end,
      }

      return true
    end,
    [Picker.fzf_lua] = function()
      local has_fzf_lua, fzf_lua = pcall(require, "fzf-lua")
      if not has_fzf_lua then
        return false
      end

      search_opts.escape_path = true
      local cmd = search.build_find_cmd(".", nil, search_opts)
      fzf_lua.files { cmd = table.concat(cmd, " "), cwd = tostring(client.dir) }

      return true
    end,
    [Picker.fzf] = function()
      search_opts.escape_path = true
      local cmd = search.build_find_cmd(dir, nil, search_opts)
      local fzf_options = { source = table.concat(cmd, " "), sink = "e" }

      local ok, res = pcall(function()
        vim.api.nvim_call_function("fzf#run", {
          vim.api.nvim_call_function("fzf#wrap", { fzf_options }),
        })
      end)

      if not ok then
        if string.find(tostring(res), "Unknown function", 1, true) ~= nil then
          return false
        else
          error(res)
        end
      end

      return true
    end,
    [Picker.mini] = function()
      -- Check if mini.pick is available
      local has_mini_pick, mini_pick = pcall(require, "mini.pick")
      if not has_mini_pick then
        return false
      end

      -- Use mini.pick's file picker
      mini_pick.builtin.files({}, { source = { cwd = tostring(client.dir) } })

      return true
    end,
  }
end
