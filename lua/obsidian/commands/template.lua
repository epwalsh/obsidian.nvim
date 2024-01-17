local Path = require "plenary.path"
local search = require "obsidian.search"
local templates = require "obsidian.templates"
local log = require "obsidian.log"
local util = require "obsidian.util"
local iter = require("obsidian.itertools").iter

---@param client obsidian.Client
return function(client, data)
  local templates_dir = client:templates_dir()

  if templates_dir == nil then
    log.err "Templates folder is not defined or does not exist"
    return
  end

  -- We need to get this upfront before
  -- Telescope hijacks the current window
  local insert_location = util.get_active_window_cursor_location()

  local function insert_template(name)
    templates.insert_template(name, client, insert_location)
  end

  if string.len(data.args) > 0 then
    local template_name = data.args
    local path = templates_dir / template_name
    if path:is_file() then
      insert_template(data.args)
    else
      log.err "Not a valid template file"
    end
    return
  end

  local search_opts =
    search.SearchOpts.from_tbl { sort_by = client.opts.sort_by, sort_reversed = client.opts.sort_reversed }

  client:_run_with_finder_backend {
    ["telescope.nvim"] = function()
      -- try with telescope.nvim
      local has_telescope, _ = pcall(require, "telescope.builtin")
      if not has_telescope then
        return false
      end

      local choose_template = function()
        local opts = {
          cwd = tostring(templates_dir),
          attach_mappings = function(_, map)
            -- NOTE: in newer versions of Telescope we can make a single call to `map()` with
            -- `mode = { "i", "n" }`, but older versions expect mode to be string, not a table.
            for mode in iter { "i", "n" } do
              map(mode, "<CR>", function(prompt_bufnr)
                local template = require("telescope.actions.state").get_selected_entry()
                require("telescope.actions").close(prompt_bufnr)
                insert_template(template[1])
              end)
            end
            return true
          end,
          find_command = search.build_find_cmd(".", nil, search_opts),
        }
        require("telescope.builtin").find_files(opts)
      end

      choose_template()

      return true
    end,
    ["fzf-lua"] = function()
      -- try with fzf-lua
      local has_fzf_lua, fzf_lua = pcall(require, "fzf-lua")
      if not has_fzf_lua then
        return false
      end

      search_opts.escape_path = true
      local cmd = search.build_find_cmd(".", nil, search_opts)

      fzf_lua.files {
        cmd = table.concat(cmd, " "),
        cwd = tostring(templates_dir),
        file_icons = false,
        actions = {
          ["default"] = function(entry)
            local template = entry[1]
            if vim.startswith(template, "  ") then
              -- With certain versions of fzf and fzf-lua, fzf-lua passes the filename
              -- with 6 characters that usually appear as 2 whitespace characters. So the actual
              -- filename starts at the 7th character.
              template = string.sub(template, 7)
            end
            insert_template(template)
          end,
        },
      }

      return true
    end,
    ["fzf.vim"] = function()
      vim.api.nvim_create_user_command("ApplyTemplate", function(path)
        -- remove escaped whitespace and extract the file name
        local file_path = string.gsub(path.args, "\\ ", " ")
        local template = vim.fs.basename(file_path)
        insert_template(template)
        vim.api.nvim_del_user_command "ApplyTemplate"
      end, { nargs = 1, bang = true })

      search_opts.escape_path = true
      local cmd = search.build_find_cmd(tostring(templates_dir), nil, search_opts)
      local fzf_options = { source = table.concat(cmd, " "), sink = "ApplyTemplate" }

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
    ["mini.pick"] = function()
      -- Check if mini.pick is available
      local has_mini_pick, mini_pick = pcall(require, "mini.pick")
      if not has_mini_pick then
        return false
      end

      -- Use mini.pick's file picker
      local chosen_template = mini_pick.builtin.files({}, { source = { cwd = tostring(client:templates_dir()) } })

      -- Check if the chosen template is a valid file
      local path = Path:new(client:templates_dir()) / chosen_template
      if path:is_file() then
        -- Insert the content of the chosen template into the current buffer
        insert_template(chosen_template)
        -- Delete the template buffer because
        -- mini.pick's default behavior is to open in a new buffer
        vim.api.nvim_command "silent! bdelete"
      else
        log.err "Not a valid template file"
      end

      return true
    end,
  }
end
