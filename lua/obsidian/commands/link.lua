local Note = require "obsidian.note"
local log = require "obsidian.log"
local util = require "obsidian.util"
local iter = require("obsidian.itertools").iter
local picker_utils = require "obsidian.picker_utils"
local Picker = require("obsidian.config").Picker

---@param client obsidian.Client
return function(client, data)
  local _, csrow, cscol, _ = unpack(assert(vim.fn.getpos "'<"))
  local _, cerow, cecol, _ = unpack(assert(vim.fn.getpos "'>"))

  if data.line1 ~= csrow or data.line2 ~= cerow then
    log.err "ObsidianLink must be called with visual selection"
    return
  end

  local lines = vim.fn.getline(csrow, cerow)
  if #lines ~= 1 then
    log.err "Only in-line visual selections allowed"
    return
  end

  local line = assert(lines[1])

  ---@param note obsidian.Note
  local function insert_ref(note)
    line = string.sub(line, 1, cscol - 1)
      .. "[["
      .. tostring(note.id)
      .. "|"
      .. string.sub(line, cscol, cecol)
      .. "]]"
      .. string.sub(line, cecol + 1)
    vim.api.nvim_buf_set_lines(0, csrow - 1, csrow, false, { line })
  end

  ---@type string
  local search_term
  if string.len(data.args) > 0 then
    search_term = data.args
  else
    search_term = string.sub(line, cscol, cecol)
  end

  -- Try to resolve the search term to a single note.
  local note = client:resolve_note(search_term)

  if note ~= nil then
    return insert_ref(note)
  end

  -- Otherwise run the preferred picker to search for notes.
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

  client:_run_with_picker_backend {
    [Picker.telescope] = function()
      -- try with telescope.nvim
      local has_telescope, telescope = pcall(require, "telescope.builtin")
      if not has_telescope then
        return false
      end

      local vimgrep_arguments =
        vim.tbl_flatten { base_cmd, {
          "--with-filename",
          "--color=never",
        } }

      telescope.grep_string {
        cwd = tostring(client.dir),
        search = search_term,
        vimgrep_arguments = vimgrep_arguments,
        attach_mappings = function(_, map)
          -- NOTE: in newer versions of Telescope we can make a single call to `map()` with
          -- `mode = { "i", "n" }`, but older versions expect mode to be string, not a table.
          for mode in iter { "i", "n" } do
            map(mode, "<CR>", function(prompt_bufnr)
              local path = require("telescope.actions.state").get_selected_entry().filename
              require("telescope.actions").close(prompt_bufnr)
              insert_ref(Note.from_file(client.dir / path))
              client:update_ui()
            end)
          end
          return true
        end,
      }

      return true
    end,
    [Picker.fzf_lua] = function()
      -- try with fzf-lua
      local has_fzf_lua, fzf_lua = pcall(require, "fzf-lua")
      if not has_fzf_lua then
        return false
      end

      fzf_lua.grep {
        cwd = tostring(client.dir),
        search = search_term,
        file_icons = false,
        actions = {
          ["default"] = function(entry)
            entry = picker_utils.fzf_lua_clean_selection(entry[1])
            local path_end = assert(string.find(entry, ":", 1, true))
            local path = string.sub(entry, 1, path_end - 1)
            insert_ref(Note.from_file(client.dir / path))
          end,
        },
      }

      return true
    end,
    [Picker.fzf] = function()
      vim.api.nvim_create_user_command("ObsInsertLink", function(d)
        -- remove escaped whitespace and extract the file name
        local result = string.gsub(d.args, "\\ ", " ")
        local path_end = assert(string.find(result, ":", 1, true))
        local path = string.sub(result, 1, path_end - 1)
        insert_ref(Note.from_file(path))
        client:update_ui()
        vim.api.nvim_del_user_command "ObsInsertLink"
      end, { nargs = 1, bang = true })

      local grep_cmd = vim.tbl_flatten {
        base_cmd,
        {
          "--",
          util.quote(search_term),
          vim.fn.fnameescape(tostring(client.dir)),
        },
      }

      local fzf_options = { source = table.concat(grep_cmd, " "), sink = "ObsInsertLink" }

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

      local result = mini_pick.builtin.grep({ pattern = search_term }, { source = { cwd = tostring(client.dir) } })
      if not result then
        return true
      end

      local path_end = assert(string.find(result, ":", 1, true))
      local path = string.sub(result, 1, path_end - 1)

      -- Delete the template buffer because
      -- mini.pick's default behavior is to open in a new buffer
      vim.api.nvim_command "silent! bdelete"

      insert_ref(Note.from_file(client.dir / path))
      client:update_ui()

      return true
    end,
  }
end
