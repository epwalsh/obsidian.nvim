local Path = require "plenary.path"
local Note = require "obsidian.note"
local echo = require "obsidian.echo"
local util = require "obsidian.util"
local search = require "obsidian.search"
local run_job = require("obsidian.async").run_job
local iter = util.iter

local M = {
  commands = {},
}

---@class obsidian.CommandConfig
---@field opts table
---@field complete function|?
---@field func function(obsidian.Client, table)

---Register a new command.
---@param name string
---@param config obsidian.CommandConfig
M.register = function(name, config)
  M.commands[name] = config
end

---Install all commands.
---
---@param client obsidian.Client
M.install = function(client)
  for command_name, command_config in pairs(M.commands) do
    local func = function(data)
      command_config.func(client, data)
    end

    if command_config.complete ~= nil then
      command_config.opts.complete = function(arg_lead, cmd_line, cursor_pos)
        return command_config.complete(client, arg_lead, cmd_line, cursor_pos)
      end
    end

    vim.api.nvim_create_user_command(command_name, func, command_config.opts)
  end
end

---@param client obsidian.Client
---@return string[]
M.complete_args_search = function(client, _, cmd_line, _)
  local search_
  local cmd_arg, _ = util.strip(string.gsub(cmd_line, "^.*Obsidian[A-Za-z0-9]+", ""))
  if string.len(cmd_arg) > 0 then
    if string.find(cmd_arg, "|", 1, true) then
      return {}
    else
      search_ = cmd_arg
    end
  else
    local _, csrow, cscol, _ = unpack(vim.fn.getpos "'<")
    local _, cerow, cecol, _ = unpack(vim.fn.getpos "'>")
    local lines = vim.fn.getline(csrow, cerow)
    assert(type(lines) == "table")

    if #lines > 1 then
      lines[1] = string.sub(lines[1], cscol)
      lines[#lines] = string.sub(lines[#lines], 1, cecol)
    elseif #lines == 1 then
      lines[1] = string.sub(lines[1], cscol, cecol)
    else
      return {}
    end

    search_ = table.concat(lines, " ")
  end

  local completions = {}
  local search_lwr = string.lower(search_)
  for note in iter(client:search(search_)) do
    local note_path = tostring(note.path:make_relative(tostring(client.dir)))
    if string.find(note:display_name(), search_lwr, 1, true) then
      table.insert(completions, note:display_name() .. "  " .. note_path)
    else
      for _, alias in pairs(note.aliases) do
        if string.find(string.lower(alias), search_lwr, 1, true) then
          table.insert(completions, alias .. "  " .. note_path)
          break
        end
      end
    end
  end

  return completions
end

M.complete_args_id = function(_, _, cmd_line, _)
  local cmd_arg, _ = util.strip(string.gsub(cmd_line, "^.*Obsidian[A-Za-z0-9]+", ""))
  if string.len(cmd_arg) > 0 then
    return {}
  else
    local note_id = util.cursor_link()
    if note_id == nil then
      local bufpath = vim.api.nvim_buf_get_name(vim.fn.bufnr())
      local note = Note.from_file(bufpath)
      note_id = note.id
    end
    return { note_id }
  end
end

---Check the directory for notes with missing/invalid frontmatter.
M.register("ObsidianCheck", {
  opts = { nargs = 0 },
  ---@param client obsidian.Client
  func = function(client, _)
    local AsyncExecutor = require("obsidian.async").AsyncExecutor
    local scan = require "plenary.scandir"

    local skip_dirs = {}
    if client.opts.templates ~= nil and client.opts.templates.subdir ~= nil then
      skip_dirs[#skip_dirs + 1] = Path:new(client.opts.templates.subdir)
    end

    local executor = AsyncExecutor.new()
    local count = 0
    local errors = {}
    local warnings = {}

    ---@param path Path
    local function check_note(path, relative_path)
      local ok, res = pcall(Note.from_file_async, path, client.dir)
      if not ok then
        errors[#errors + 1] = "Failed to parse note '" .. relative_path .. "': " .. tostring(res)
      elseif res.has_frontmatter == false then
        warnings[#warnings + 1] = "'" .. relative_path .. "' missing frontmatter"
      end
      count = count + 1
    end

    ---@diagnostic disable-next-line: undefined-field
    local start_time = vim.loop.hrtime()

    scan.scan_dir(vim.fs.normalize(tostring(client.dir)), {
      hidden = false,
      add_dirs = false,
      respect_gitignore = true,
      search_pattern = ".*%.md",
      on_insert = function(entry)
        local relative_path = Path:new(entry):make_relative(tostring(client.dir))
        for skip_dir in iter(skip_dirs) do
          if vim.startswith(relative_path, tostring(skip_dir) .. skip_dir._sep) then
            return
          end
        end
        executor:submit(check_note, nil, entry, relative_path)
      end,
    })

    executor:join_and_then(5000, function()
      ---@diagnostic disable-next-line: undefined-field
      local runtime = math.floor((vim.loop.hrtime() - start_time) / 1000000)
      local messages = { "Checked " .. tostring(count) .. " notes in " .. runtime .. "ms" }
      local log_level = vim.log.levels.INFO
      if #warnings > 0 then
        messages[#messages + 1] = "\nThere were " .. tostring(#warnings) .. " warning(s):"
        log_level = vim.log.levels.WARN
        for warning in iter(warnings) do
          messages[#messages + 1] = "  " .. warning
        end
      end
      if #errors > 0 then
        messages[#messages + 1] = "\nThere were " .. tostring(#errors) .. " error(s):"
        for err in iter(errors) do
          messages[#messages + 1] = "  " .. err
        end
        log_level = vim.log.levels.ERROR
      end
      echo.echo(table.concat(messages, "\n"), log_level)
    end)
  end,
})

---Create or open a new daily note.
M.register("ObsidianToday", {
  opts = { nargs = 0 },
  func = function(client, _)
    local note = client:today()
    local open_in = util.get_open_strategy(client.opts.open_notes_in)
    vim.api.nvim_command(open_in .. tostring(note.path))
  end,
})

---Create (or open) the daily note from the last weekday.
M.register("ObsidianYesterday", {
  opts = { nargs = 0 },
  func = function(client, _)
    local note = client:yesterday()
    local open_in = util.get_open_strategy(client.opts.open_notes_in)
    vim.api.nvim_command(open_in .. tostring(note.path))
  end,
})

---Create a new note.
M.register("ObsidianNew", {
  func = function(client, data)
    ---@type obsidian.Note
    local note
    local open_in = util.get_open_strategy(client.opts.open_notes_in)
    if data.args:len() > 0 then
      note = client:new_note(data.args)
    else
      note = client:new_note()
    end
    vim.api.nvim_command(open_in .. tostring(note.path))
  end,
  opts = { nargs = "?" },
})

---Open a note in the Obsidian app.
M.register("ObsidianOpen", {
  opts = { nargs = "?" },
  complete = M.complete_args_search,
  func = function(client, data)
    local vault = client:vault()
    if vault == nil then
      echo.err("couldn't find an Obsidian vault", client.opts.log_level)
      return
    end

    local vault_name = vim.fs.basename(vault)
    assert(vault_name)

    local path
    if data.args:len() > 0 then
      local note = client:resolve_note(data.args)
      if note ~= nil then
        path = note.path:make_relative(vault)
      else
        echo.err("Could not resolve arguments to a note ID, path, or alias", client.opts.log_level)
        return
      end
    else
      -- bufname is an absolute path to the buffer.
      local bufname = vim.api.nvim_buf_get_name(0)
      local vault_name_escaped = vault_name:gsub("%W", "%%%0") .. "%/"
      ---@diagnostic disable-next-line: undefined-field
      if vim.loop.os_uname().sysname == "Windows_NT" then
        bufname = bufname:gsub("/", "\\")
        vault_name_escaped = vault_name_escaped:gsub("/", [[\%\]])
      end

      path = Path:new(bufname):make_relative(vault)

      -- `make_relative` fails to work when vault path is configured to look behind a link
      -- and returns an unaltered path if it cannot make the path relative.
      if path == bufname then
        -- If the vault name appears in the output of `make_relative`, i.e. `make_relative` has failed,
        -- then remove everything up to and including the vault path
        -- Example:
        -- Config path: ~/Dropbox/Documents/0-obsidian-notes/
        -- File path: /Users/username/Library/CloudStorage/Dropbox/Documents/0-obsidian-notes/Notes/note.md
        --                                                                   ^
        -- Proper relative path: Notes/note.md
        local _, j = path:find(vault_name_escaped)
        if j ~= nil then
          path = bufname:sub(j)
        end
      end
    end

    local encoded_vault = util.urlencode(vault_name)
    local encoded_path = util.urlencode(tostring(path))

    local uri
    if client.opts.use_advanced_uri then
      local line = vim.api.nvim_win_get_cursor(0)[1] or 1
      uri = ("obsidian://advanced-uri?vault=%s&filepath=%s&line=%i"):format(encoded_vault, encoded_path, line)
    else
      uri = ("obsidian://open?vault=%s&file=%s"):format(encoded_vault, encoded_path)
    end

    local cmd = nil
    local args = {}
    local sysname = vim.loop.os_uname().sysname
    local release = vim.loop.os_uname().release
    if sysname == "Linux" then
      if string.find(release, "microsoft") then
        cmd = "wsl-open"
      else
        cmd = "xdg-open"
      end
      args = { uri }
    elseif sysname == "Darwin" then
      cmd = "open"
      if client.opts.open_app_foreground then
        args = { "-a", "/Applications/Obsidian.app", uri }
      else
        args = { "-a", "/Applications/Obsidian.app", "--background", uri }
      end
    elseif sysname == "Windows_NT" then
      cmd = "powershell"
      args = { "Start-Process '" .. uri .. "'" }
    end

    if cmd == nil then
      echo.err("open command does not support this OS yet", client.opts.log_level)
      return
    end

    run_job(cmd, args)
  end,
})

---Get backlinks to a note.
M.register("ObsidianBacklinks", {
  opts = { nargs = 0 },
  func = function(client, _)
    local ok, backlinks = pcall(function()
      return require("obsidian.backlinks").new(client)
    end)
    if ok then
      echo.info(
        ("Showing backlinks '%s'. Hit ENTER on a line to follow the backlink."):format(tostring(backlinks.note.id)),
        client.opts.log_level
      )
      backlinks:view()
    else
      echo.err("Backlinks command can only be used from a valid note", client.opts.log_level)
    end
  end,
})

---Search notes.
M.register("ObsidianSearch", {
  opts = { nargs = "?" },
  func = function(client, data)
    local base_cmd =
      vim.tbl_flatten { search.SEARCH_CMD, { "--smart-case", "--column", "--line-number", "--no-heading" } }

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
            tostring(client.dir),
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
    }
  end,
})

--- Insert a template
M.register("ObsidianTemplate", {
  opts = { nargs = "?" },
  func = function(client, data)
    if client.templates_dir == nil then
      echo.err("Templates folder is not defined or does not exist", client.opts.log_level)
      return
    end

    -- We need to get this upfront before
    -- Telescope hijacks the current window
    local insert_location = util.get_active_window_cursor_location()

    local function insert_template(name)
      util.insert_template(name, client, insert_location)
    end

    if string.len(data.args) > 0 then
      local template_name = data.args
      local path = Path:new(client.templates_dir) / template_name
      if path:is_file() then
        insert_template(data.args)
      else
        echo.err("Not a valid template file", client.opts.log_level)
      end
      return
    end

    client:_run_with_finder_backend {
      ["telescope.nvim"] = function()
        -- try with telescope.nvim
        local has_telescope, _ = pcall(require, "telescope.builtin")
        if not has_telescope then
          return false
        end

        local choose_template = function()
          local opts = {
            cwd = tostring(client.templates_dir),
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
            find_command = search.build_find_cmd(".", client.opts.sort_by, client.opts.sort_reversed),
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

        local cmd = search.build_find_cmd(".", client.opts.sort_by, client.opts.sort_reversed)
        fzf_lua.files {
          cmd = util.table_params_to_str(cmd),
          cwd = tostring(client.templates_dir),
          file_icons = false,
          actions = {
            ["default"] = function(entry)
              -- for some reason fzf-lua passes the filename with 6 characters
              -- at the start that appear on screen as 2 whitespace characters
              -- so we need to start on the 7th character
              local template = entry[1]:sub(7)
              insert_location(template)
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

        local cmd =
          search.build_find_cmd(tostring(client.templates_dir), client.opts.sort_by, client.opts.sort_reversed)
        local fzf_options = { source = util.table_params_to_str(cmd), sink = "ApplyTemplate" }

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
    }
  end,
})

---Quick switch to an obsidian note
M.register("ObsidianQuickSwitch", {
  opts = { nargs = 0 },
  func = function(client, _)
    local dir = tostring(client.dir)

    client:_run_with_finder_backend {
      ["telescope.nvim"] = function()
        local has_telescope, telescope = pcall(require, "telescope.builtin")
        if not has_telescope then
          return false
        end
        -- Search with telescope.nvim
        telescope.find_files {
          cwd = dir,
          search_file = "*.md",
          find_command = search.build_find_cmd(".", client.opts.sort_by, client.opts.sort_reversed),
        }

        return true
      end,
      ["fzf-lua"] = function()
        local has_fzf_lua, fzf_lua = pcall(require, "fzf-lua")
        if not has_fzf_lua then
          return false
        end

        local cmd = search.build_find_cmd(".", client.opts.sort_by, client.opts.sort_reversed)
        fzf_lua.files { cmd = util.table_params_to_str(cmd), cwd = tostring(client.dir) }

        return true
      end,
      ["fzf.vim"] = function()
        local cmd = search.build_find_cmd(dir, client.opts.sort_by, client.opts.sort_reversed)
        local fzf_options = { source = util.table_params_to_str(cmd), sink = "e" }

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
    }
  end,
})

---Create a new note and link to it.
M.register("ObsidianLinkNew", {
  opts = { nargs = "?", range = true },
  func = function(client, data)
    local _, csrow, cscol, _ = unpack(vim.fn.getpos "'<")
    local _, cerow, cecol, _ = unpack(vim.fn.getpos "'>")

    if data.line1 ~= csrow or data.line2 ~= cerow then
      echo.err("ObsidianLink must be called with visual selection", client.opts.log_level)
      return
    end

    local lines = vim.fn.getline(csrow, cerow)
    if #lines ~= 1 then
      echo.err("Only in-line visual selections allowed", client.opts.log_level)
      return
    end

    local line = lines[1]

    local title
    if string.len(data.args) > 0 then
      title = data.args
    else
      title = string.sub(line, cscol, cecol)
    end
    local note = client:new_note(title, nil, vim.fn.expand "%:p:h")

    line = string.sub(line, 1, cscol - 1)
      .. "[["
      .. tostring(note.id)
      .. "|"
      .. string.sub(line, cscol, cecol)
      .. "]]"
      .. string.sub(line, cecol + 1)
    vim.api.nvim_buf_set_lines(0, csrow - 1, csrow, false, { line })
  end,
})

M.register("ObsidianLink", {
  opts = { nargs = "?", range = true },
  complete = M.complete_args_search,
  func = function(client, data)
    local _, csrow, cscol, _ = unpack(vim.fn.getpos "'<")
    local _, cerow, cecol, _ = unpack(vim.fn.getpos "'>")

    if data.line1 ~= csrow or data.line2 ~= cerow then
      echo.err("ObsidianLink must be called with visual selection", client.opts.log_level)
      return
    end

    local lines = vim.fn.getline(csrow, cerow)
    if #lines ~= 1 then
      echo.err("Only in-line visual selections allowed", client.opts.log_level)
      return
    end

    local line = lines[1]

    ---@type obsidian.Note|?
    local note
    if string.len(data.args) > 0 then
      note = client:resolve_note(data.args)
    else
      note = client:resolve_note(string.sub(line, cscol, cecol))
    end

    if note == nil then
      echo.err("Could not resolve argument to a note ID, alias, or path", client.opts.log_level)
      return
    end

    line = string.sub(line, 1, cscol - 1)
      .. "[["
      .. tostring(note.id)
      .. "|"
      .. string.sub(line, cscol, cecol)
      .. "]]"
      .. string.sub(line, cecol + 1)
    vim.api.nvim_buf_set_lines(0, csrow - 1, csrow, false, { line })
  end,
})

---Follow link under cursor.
M.register("ObsidianFollowLink", {
  opts = { nargs = 0 },
  func = function(client, _)
    local note_file_name, note_name = util.cursor_link()
    if note_file_name == nil then
      return
    end

    -- Check if it's a URL.
    if note_file_name:match "^[%a%d]*%:%/%/" then
      if client.opts.follow_url_func ~= nil then
        client.opts.follow_url_func(note_file_name)
      else
        echo.warn(
          "This looks like a URL. You can customize the behavior of URLs with the 'follow_url_func' option.",
          client.opts.log_level
        )
      end
      return
    end

    -- Remove links from the end if there are any.
    local header_link = note_file_name:match "#[%a%d%s-_^]+$"
    if header_link ~= nil then
      note_file_name = note_file_name:sub(1, -header_link:len() - 1)
    end

    -- Ensure file name ends with suffix.
    if not note_file_name:match "%.md" then
      note_file_name = note_file_name .. ".md"
    end

    -- Search for matching notes.
    search.find_notes_async(client.dir, note_file_name, function(notes)
      if #notes < 1 then
        local aliases = note_name == note_file_name and {} or { note_name }
        local note = client:new_note(note_file_name, nil, nil, aliases)
        vim.schedule(function()
          vim.api.nvim_command("e " .. tostring(note.path))
        end)
      elseif #notes == 1 then
        local path = notes[1]
        vim.schedule(function()
          vim.api.nvim_command("e " .. tostring(path))
        end)
      else
        echo.err("Multiple notes with this name exist", client.opts.log_level)
        return
      end
    end)
  end,
})

---Run a health check.
M.register("ObsidianCheckHealth", {
  opts = { nargs = 0 },
  func = function(client, _)
    local errors = 0

    local vault = client:vault()
    if vault == nil then
      errors = errors + 1
      echo.err("FAILED - couldn't find an Obsidian vault in '" .. tostring(client.dir) .. "'", client.opts.log_level)
    end

    -- Check completion via nvim-cmp
    if client.opts.completion.nvim_cmp then
      local ok, cmp = pcall(require, "cmp")
      if not ok then
        echo.err("nvim-cmp could not be loaded", client.opts.log_level)
      else
        local has_obsidian_source = false
        local has_obsidian_new_source = false
        for _, source in pairs(cmp.get_config().sources) do
          if source.name == "obsidian" then
            has_obsidian_source = true
          elseif source.name == "obsidian_new" then
            has_obsidian_new_source = true
          end
        end

        if not has_obsidian_source then
          echo.err("FAILED - note completion is not configured", client.opts.log_level)
          errors = errors + 1
        end

        if not has_obsidian_new_source then
          echo.err("FAILED - new note completion is not configured", client.opts.log_level)
          errors = errors + 1
        end
      end
    end

    -- Report total errors.
    if errors == 1 then
      echo.err("There was 1 error with obsidian setup", client.opts.log_level)
    elseif errors > 1 then
      echo.err("There were " .. tostring(errors) .. " errors with obsidian setup", client.opts.log_level)
    else
      echo.info("All good!\nVault configured to '" .. vault .. "'", client.opts.log_level)
    end
  end,
})

M.register("ObsidianWorkspace", {
  opts = { nargs = "?" },
  func = function(client, data)
    if not data.args or #data.args == 0 then
      echo.info(
        "Current workspace: " .. client.current_workspace.name .. " @ " .. tostring(client.dir),
        client.opts.log_level
      )
      return
    end

    local workspace = nil
    for _, value in pairs(client.opts.workspaces) do
      if data.args == value.name then
        workspace = value
      end
    end

    if not workspace then
      echo.err("Workspace '" .. data.args .. "' does not exist", client.opts.log_level)
      return
    end

    client.current_workspace = workspace

    echo.info("Switching to workspace '" .. workspace.name .. "' (" .. workspace.path .. ")", client.opts.log_level)
    -- NOTE: workspace.path has already been normalized
    client.dir = Path:new(workspace.path)
  end,
})

M.register("ObsidianRename", {
  opts = { nargs = 1 },
  complete = M.complete_args_id,
  func = function(client, data)
    local AsyncExecutor = require("obsidian.async").AsyncExecutor
    local File = require("obsidian.async").File

    local dry_run = false
    local arg = util.strip_whitespace(data.args)
    if vim.endswith(arg, " --dry-run") then
      dry_run = true
      arg = util.strip_whitespace(string.sub(arg, 1, -string.len " --dry-run" - 1))
    end

    local is_current_buf
    local cur_note_path
    local dirname
    local cur_note_id = util.cursor_link()
    if cur_note_id == nil then
      is_current_buf = true
      local bufpath = vim.api.nvim_buf_get_name(vim.fn.bufnr())
      cur_note_path = bufpath
      local note = Note.from_file(bufpath)
      cur_note_id = tostring(note.id)
      dirname = vim.fs.dirname(bufpath)
    else
      is_current_buf = false
      local note = client:resolve_note(cur_note_id)
      if note == nil then
        echo.err("Could not resolve note '" .. cur_note_id .. "'")
        return
      end
      cur_note_id = tostring(note.id)
      cur_note_path = tostring(note.path:absolute())
      dirname = vim.fs.dirname(cur_note_path)
    end

    -- TODO: handle case where new_note_id is a path containing one or more directories.
    local new_note_id = arg
    if vim.endswith(new_note_id, ".md") then
      new_note_id = string.sub(new_note_id, 1, -4)
    end
    local new_note_path = vim.fs.joinpath(dirname, new_note_id .. ".md")

    if new_note_id == cur_note_id then
      echo.warn "New note ID is the same, doing nothing"
      return
    end

    -- Get confirmation before continuing.
    local confirmation
    if not dry_run then
      confirmation = string.lower(vim.fn.input {
        prompt = "Renaming '"
          .. cur_note_id
          .. "' to '"
          .. new_note_id
          .. "'...\n"
          .. "This will write all buffers and potentially modify a lot of files. If you're using version control "
          .. "with your vault it would be a good idea to commit the current state of your vault before running this.\n"
          .. "You can also do a dry run of this by running ':ObsidianRename "
          .. arg
          .. " --dry-run'.\n"
          .. "Do you want to continue? [Y/n] ",
      })
    else
      confirmation = string.lower(vim.fn.input {
        prompt = "Dry run: renaming '"
          .. cur_note_id
          .. "' to '"
          .. new_note_id
          .. "'...\n"
          .. "Do you want to continue? [Y/n] ",
      })
    end
    if not (confirmation == "y" or confirmation == "yes") then
      echo.warn "Rename canceled, doing nothing"
      return
    end

    ---@param fn function
    local function quietly(fn, ...)
      client._quiet = true
      local ok, res = pcall(fn, ...)
      client._quiet = false
      if not ok then
        error(res)
      end
    end

    -- Write all buffers.
    -- TODO: is there a way to only write markdown buffers in the vault dir?
    quietly(vim.cmd.wall)

    -- If we're renaming the note of the current buffer, save as the new path.
    -- TODO: handle case where we're renaming the note of another buffer.
    if is_current_buf then
      if not dry_run then
        quietly(vim.cmd.saveas, new_note_path)
        vim.fn.delete(cur_note_path)
      else
        echo.info(
          "Dry run: saving current buffer as '" .. new_note_path .. "' and removing old file '" .. cur_note_path .. "'"
        )
      end
    end

    local cur_note_rel_path = tostring(Path:new(cur_note_path):make_relative(tostring(client.dir)))
    local new_note_rel_path = tostring(Path:new(new_note_path):make_relative(tostring(client.dir)))

    -- Search notes on disk for any references to `cur_note_id`.
    -- We look for the following forms of references:
    -- * '[[cur_note_id]]'
    -- * '[[cur_note_id|ALIAS]]'
    -- * '[[cur_note_id\|ALIAS]]' (a wiki link within a table)
    -- * '[ALIAS](cur_note_id)'
    -- And all of the above with relative paths (from the vault root) to the note instead of just the note ID,
    -- with and without the ".md" suffix.
    -- Another possible form is [[ALIAS]], but we don't change the note's aliases when renaming
    -- so those links will still be valid.
    ---@param ref_link string
    ---@return string[]
    local function get_ref_forms(ref_link)
      return { "[[" .. ref_link .. "]]", "[[" .. ref_link .. "|", "[[" .. ref_link .. "\\|", "](" .. ref_link .. ")" }
    end

    local reference_forms = vim.tbl_flatten {
      get_ref_forms(cur_note_id),
      get_ref_forms(cur_note_rel_path),
      get_ref_forms(string.sub(cur_note_rel_path, 1, -4)),
    }
    local replace_with = vim.tbl_flatten {
      get_ref_forms(new_note_id),
      get_ref_forms(new_note_rel_path),
      get_ref_forms(string.sub(new_note_rel_path, 1, -4)),
    }

    local executor = AsyncExecutor.new()

    local file_count = 0
    local replacement_count = 0
    local all_tasks_submitted = false

    ---@param path string
    ---@return integer
    local function replace_refs(path)
      --- Read lines, replacing refs as we go.
      local count = 0
      local lines = {}
      local f = File.open(path, "r")
      for line_num, line in util.enumerate(f:lines(true)) do
        for ref, replacement in util.zip(reference_forms, replace_with) do
          local n
          line, n = util.string_replace(line, ref, replacement)
          if dry_run and n > 0 then
            echo.info(
              "Dry run: '"
                .. path
                .. "':"
                .. line_num
                .. " Replacing "
                .. n
                .. " occurrence(s) of '"
                .. ref
                .. "' with '"
                .. replacement
                .. "'"
            )
          end
          count = count + n
        end
        lines[#lines + 1] = line
      end
      f:close()

      --- Write the new lines back.
      if not dry_run and count > 0 then
        f = File.open(path, "w")
        f:write_lines(lines)
        f:close()
      end

      return count
    end

    local function on_search_match(match)
      local path = vim.fs.normalize(match.path.text)
      file_count = file_count + 1
      executor:submit(replace_refs, function(count)
        replacement_count = replacement_count + count
      end, path)
    end

    search.search_async(client.dir, reference_forms, { "-m=1" }, on_search_match, function(_)
      all_tasks_submitted = true
    end)

    -- Wait for all tasks to get submitted.
    vim.wait(2000, function()
      return all_tasks_submitted
    end, 50, false)

    -- Then block until all tasks are finished.
    executor:join(2000)

    local prefix = dry_run and "Dry run: replaced " or "Replaced "
    echo.info(prefix .. replacement_count .. " reference(s) across " .. file_count .. " file(s)")

    -- In case the files of any current buffers were changed.
    vim.cmd.checktime()
  end,
})

return M
