local util = require "obsidian.util"

---@param client obsidian.Client
return function(client, data)
  local base_cmd = {
    "rg",
    "--no-config",
    "--fixed-strings",
    "--type=md",
    "--smart-case",
    "--column",
    "--line-number",
    "--no-heading",
  }

  client:_run_with_finder_backend {
    ["telescope.nvim"] = function()
      local has_telescope, telescope = pcall(require, "telescope.builtin")

      if not has_telescope then
        return false
      end

      -- Search with telescope.nvim
      local vimgrep_arguments =
        vim.tbl_flatten { base_cmd, {
          "--with-filename",
          "--color=never",
        } }

      if data.args:len() > 0 then
        telescope.grep_string {
          cwd = tostring(client.dir),
          search = data.args,
          vimgrep_arguments = vimgrep_arguments,
        }
      else
        telescope.live_grep { cwd = tostring(client.dir), vimgrep_arguments = vimgrep_arguments }
      end

      return true
    end,
    ["fzf-lua"] = function()
      local has_fzf_lua, fzf_lua = pcall(require, "fzf-lua")
      if not has_fzf_lua then
        return false
      end

      if data.args:len() > 0 then
        fzf_lua.grep { cwd = tostring(client.dir), search = data.args }
      else
        fzf_lua.live_grep { cwd = tostring(client.dir), exec_empty_query = true }
      end

      return true
    end,
    ["fzf.vim"] = function()
      local grep_cmd = vim.tbl_flatten {
        base_cmd,
        {
          "--color=always",
          "--",
          util.quote(data.args),
          vim.fn.fnameescape(tostring(client.dir)),
        },
      }

      local ok, res = pcall(function()
        vim.api.nvim_call_function("fzf#vim#grep", {
          table.concat(grep_cmd, " "),
          vim.api.nvim_call_function("fzf#vim#with_preview", {}),
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
    ["mini.pick"] = function()
      -- Check if mini.pick is available
      local has_mini_pick, mini_pick = pcall(require, "mini.pick")
      if not has_mini_pick then
        return false
      end

      -- Use mini.pick's grep_live or grep picker depending on whether there are arguments
      if data.args:len() > 0 then
        mini_pick.builtin.grep({ pattern = data.args }, { source = { cwd = tostring(client.dir) } })
      else
        mini_pick.builtin.grep_live({}, { source = { cwd = tostring(client.dir) } })
      end

      return true
    end,
  }
end
