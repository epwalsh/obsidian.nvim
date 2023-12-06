local Path = require "plenary.path"
local Note = require "obsidian.note"
local log = require "obsidian.log"
local util = require "obsidian.util"
local search = require "obsidian.search"
local templates = require "obsidian.templates"
local run_job = require("obsidian.async").run_job
local iter = require("obsidian.itertools").iter
local enumerate = require("obsidian.itertools").enumerate
local zip = require("obsidian.itertools").zip

local RefTypes = search.RefTypes

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
  local query
  local cmd_arg, _ = util.lstrip_whitespace(string.gsub(cmd_line, "^.*Obsidian[A-Za-z0-9]+", ""))
  if string.len(cmd_arg) > 0 then
    if string.find(cmd_arg, "|", 1, true) then
      return {}
    else
      query = cmd_arg
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

    query = table.concat(lines, " ")
  end

  local completions = {}
  local query_lower = string.lower(query)
  for note in iter(client:find_notes(query, { sort = true })) do
    local note_path = assert(client:vault_relative_path(note.path))
    if string.find(string.lower(note:display_name()), query_lower, 1, true) then
      table.insert(completions, note:display_name() .. "  " .. note_path)
    else
      for _, alias in pairs(note.aliases) do
        if string.find(string.lower(alias), query_lower, 1, true) then
          table.insert(completions, alias .. "  " .. note_path)
          break
        end
      end
    end
  end

  return completions
end

M.complete_args_id = function(_, _, cmd_line, _)
  local cmd_arg, _ = util.lstrip_whitespace(string.gsub(cmd_line, "^.*Obsidian[A-Za-z0-9]+", ""))
  if string.len(cmd_arg) > 0 then
    return {}
  else
    local note_id = util.cursor_link()
    if note_id == nil then
      local bufpath = vim.api.nvim_buf_get_name(vim.fn.bufnr())
      local note = Note.from_file(bufpath)
      note_id = tostring(note.id)
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

    scan.scan_dir(vim.fs.normalize(tostring(client:vault_root())), {
      hidden = false,
      add_dirs = false,
      respect_gitignore = true,
      search_pattern = ".*%.md",
      on_insert = function(entry)
        local relative_path = assert(client:vault_relative_path(entry))
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
      log.log(table.concat(messages, "\n"), log_level)
    end)
  end,
})

---Create or open a new daily note.
M.register("ObsidianToday", {
  opts = { nargs = "?" },
  func = function(client, data)
    local offset_days = 0
    local arg = util.string_replace(data.args, " ", "")
    if string.len(arg) > 0 then
      local offset = tonumber(arg)
      if offset == nil then
        log.err "Invalid argument, expected an integer offset"
        return
      else
        offset_days = offset
      end
    end
    local note = client:daily(offset_days)
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

---Create (or open) the daily note for the next weekday.
M.register("ObsidianTomorrow", {
  opts = { nargs = 0 },
  func = function(client, _)
    local note = client:tomorrow()
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
  ---@param client obsidian.Client
  func = function(client, data)
    local vault_name = client:vault_name()
    local this_os = util.get_os()

    -- Resolve path of note to open.
    ---@type string|?
    local path
    if data.args:len() > 0 then
      local note = client:resolve_note(data.args)
      if note ~= nil then
        path = assert(client:vault_relative_path(note.path))
      else
        log.err "Could not resolve arguments to a note ID, path, or alias"
        return
      end
    else
      local cursor_link, _, ref_type = util.cursor_link()
      if cursor_link ~= nil and ref_type ~= RefTypes.NakedUrl then
        local note = client:resolve_note(cursor_link)
        if note ~= nil then
          path = assert(client:vault_relative_path(note.path))
        else
          log.err "Could not resolve link under cursor to a note ID, path, or alias"
          return
        end
      else
        -- bufname is an absolute path to the buffer.
        local bufname = vim.api.nvim_buf_get_name(0)
        path = client:vault_relative_path(bufname)
        if path == nil then
          log.err("Current buffer '" .. bufname .. "' does not appear to be inside the vault")
          return
        end
      end
    end

    -- Normalize path for windows.
    if this_os == util.OSType.Windows then
      path = string.gsub(path, "/", "\\")
    end

    local encoded_vault = util.urlencode(vault_name)
    local encoded_path = util.urlencode(path)

    local uri
    if client.opts.use_advanced_uri then
      local line = vim.api.nvim_win_get_cursor(0)[1] or 1
      uri = ("obsidian://advanced-uri?vault=%s&filepath=%s&line=%i"):format(encoded_vault, encoded_path, line)
    else
      uri = ("obsidian://open?vault=%s&file=%s"):format(encoded_vault, encoded_path)
    end

    ---@type string, string[]
    local cmd, args
    if this_os == util.OSType.Linux then
      cmd = "xdg-open"
      args = { uri }
    elseif this_os == util.OSType.Wsl then
      cmd = "wsl-open"
      args = { uri }
    elseif this_os == util.OSType.Windows then
      cmd = "powershell"
      args = { "Start-Process '" .. uri .. "'" }
    elseif this_os == util.OSType.Darwin then
      cmd = "open"
      if client.opts.open_app_foreground then
        args = { "-a", "/Applications/Obsidian.app", uri }
      else
        args = { "-a", "/Applications/Obsidian.app", "--background", uri }
      end
    else
      log.err("open command does not support OS type '" .. this_os .. "'")
      return
    end

    assert(cmd)
    assert(args)
    run_job(cmd, args)
  end,
})

---Get backlinks to a note.
M.register("ObsidianBacklinks", {
  opts = { nargs = 0 },
  func = function(client, _)
    ---@type obsidian.Note|?
    local note
    local cursor_link, _, ref_type = util.cursor_link()
    if cursor_link ~= nil and ref_type ~= RefTypes.NakedUrl then
      note = client:resolve_note(cursor_link)
      if note == nil then
        log.err "Could not resolve link under cursor to a note ID, path, or alias"
        return
      end
    end

    local ok, backlinks = pcall(function()
      return require("obsidian.backlinks").new(client, nil, nil, note)
    end)

    if ok then
      backlinks:view(function(matches)
        if not vim.tbl_isempty(matches) then
          log.info(
            "Showing backlinks to '%s'.\n\n"
              .. "TIPS:\n\n"
              .. "- Hit ENTER on a match to follow the backlink\n"
              .. "- Hit ENTER on a group header to toggle the fold, or use normal fold mappings",
            backlinks.note.id
          )
        else
          if note ~= nil then
            log.warn("No backlinks to '%s'", note.id)
          else
            log.warn "No backlinks to current note"
          end
        end
      end)
    else
      log.err "Backlinks command can only be used from a valid note"
    end
  end,
})

---Search notes.
M.register("ObsidianSearch", {
  opts = { nargs = "?" },
  func = function(client, data)
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
  ---@param client obsidian.Client
  func = function(client, data)
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

        local cmd = search.build_find_cmd(".", nil, search_opts)
        fzf_lua.files {
          cmd = table.concat(cmd, " "),
          cwd = tostring(templates_dir),
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
    }
  end,
})

---Quick switch to an obsidian note
M.register("ObsidianQuickSwitch", {
  opts = { nargs = 0 },
  ---@param client obsidian.Client
  func = function(client, _)
    local dir = tostring(client.dir)
    local search_opts =
      search.SearchOpts.from_tbl { sort_by = client.opts.sort_by, sort_reversed = client.opts.sort_reversed }

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
          find_command = search.build_find_cmd(".", nil, search_opts),
        }

        return true
      end,
      ["fzf-lua"] = function()
        local has_fzf_lua, fzf_lua = pcall(require, "fzf-lua")
        if not has_fzf_lua then
          return false
        end

        local cmd = search.build_find_cmd(".", nil, search_opts)
        fzf_lua.files { cmd = table.concat(cmd, " "), cwd = tostring(client.dir) }

        return true
      end,
      ["fzf.vim"] = function()
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
      log.err "ObsidianLink must be called with visual selection"
      return
    end

    local lines = vim.fn.getline(csrow, cerow)
    if #lines ~= 1 then
      log.err "Only in-line visual selections allowed"
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
      log.err "ObsidianLink must be called with visual selection"
      return
    end

    local lines = vim.fn.getline(csrow, cerow)
    if #lines ~= 1 then
      log.err "Only in-line visual selections allowed"
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
      log.err "Could not resolve argument to a note ID, alias, or path"
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
    local location, name, link_type = util.cursor_link(nil, nil, true)
    if location == nil then
      return
    end

    -- Check if it's a URL.
    if util.is_url(location) then
      if client.opts.follow_url_func ~= nil then
        client.opts.follow_url_func(location)
      else
        log.warn "This looks like a URL. You can customize the behavior of URLs with the 'follow_url_func' option."
      end
      return
    end

    -- Remove links from the end if there are any.
    local header_link = location:match "#[%a%d%s-_^]+$"
    if header_link ~= nil then
      location = location:sub(1, -header_link:len() - 1)
    end

    local buf_cwd = vim.fs.basename(vim.api.nvim_buf_get_name(0))

    -- Search for matching notes.
    -- TODO: handle case where there are multiple matches by prompting user to choose.
    client:resolve_note_async(location, function(note)
      if note == nil and (link_type == RefTypes.Wiki or link_type == RefTypes.WikiWithAlias) then
        vim.schedule(function()
          local confirmation = string.lower(vim.fn.input {
            prompt = "Create new note '" .. location .. "'? [Y/n] ",
          })
          if confirmation == "y" or confirmation == "yes" then
            -- Create a new note.
            local aliases = name == location and {} or { name }
            note = client:new_note(location, nil, nil, aliases)
            vim.api.nvim_command("e " .. tostring(note.path))
          else
            log.warn "Aborting"
          end
        end)
      elseif note ~= nil then
        -- Go to resolved note.
        local path = note.path
        assert(path)
        vim.schedule(function()
          vim.api.nvim_command("e " .. tostring(path))
        end)
      else
        local paths_to_check = { client:vault_root() / location, Path:new(location) }
        if buf_cwd ~= nil then
          paths_to_check[#paths_to_check + 1] = Path:new(buf_cwd) / location
        end

        for path in iter(paths_to_check) do
          if path:is_file() then
            return vim.schedule(function()
              vim.api.nvim_command("e " .. tostring(path))
            end)
          end
        end
        return log.err("Failed to resolve file '" .. location .. "'")
      end
    end)
  end,
})

M.register("ObsidianWorkspace", {
  opts = { nargs = "?" },
  func = function(client, data)
    if not data.args or #data.args == 0 then
      log.info("Current workspace: " .. client.current_workspace.name .. " @ " .. tostring(client.dir))
      return
    end

    local workspace = nil
    for _, value in pairs(client.opts.workspaces) do
      if data.args == value.name then
        workspace = value
      end
    end

    if not workspace then
      log.err("Workspace '" .. data.args .. "' does not exist")
      return
    end

    client.current_workspace = workspace

    log.info("Switching to workspace '" .. workspace.name .. "' (" .. workspace.path .. ")")
    -- NOTE: workspace.path has already been normalized
    client.dir = Path:new(workspace.path)
  end,
})

M.register("ObsidianRename", {
  opts = { nargs = 1 },
  complete = M.complete_args_id,
  ---@param client obsidian.Client
  func = function(client, data)
    local AsyncExecutor = require("obsidian.async").AsyncExecutor
    local File = require("obsidian.async").File

    -- Validate args.
    local dry_run = false
    local arg = util.strip_whitespace(data.args)
    if vim.endswith(arg, " --dry-run") then
      dry_run = true
      arg = util.strip_whitespace(string.sub(arg, 1, -string.len " --dry-run" - 1))
    end

    -- Resolve the note to rename.
    local is_current_buf
    local cur_note_bufnr
    local cur_note_path
    local cur_note
    local dirname
    local cur_note_id = util.cursor_link()
    if cur_note_id == nil then
      is_current_buf = true
      cur_note_bufnr = vim.fn.bufnr()
      cur_note_path = vim.fs.normalize(vim.api.nvim_buf_get_name(cur_note_bufnr))
      cur_note = Note.from_file(cur_note_path)
      cur_note_id = tostring(cur_note.id)
      dirname = vim.fs.dirname(cur_note_path)
    else
      is_current_buf = false
      cur_note = client:resolve_note(cur_note_id)
      if cur_note == nil then
        log.err("Could not resolve note '" .. cur_note_id .. "'")
        return
      end
      cur_note_id = tostring(cur_note.id)
      cur_note_path = vim.fs.normalize(tostring(cur_note.path:absolute()))
      dirname = vim.fs.dirname(cur_note_path)
      for bufnr, bufpath in util.get_named_buffers() do
        if bufpath == cur_note_path then
          cur_note_bufnr = bufnr
          break
        end
      end
    end

    -- Parse new note ID / path from args.
    local parts = vim.split(arg, "/", { plain = true })
    local new_note_id = parts[#parts]
    if new_note_id == "" then
      log.err "Invalid new note ID"
      return
    elseif vim.endswith(new_note_id, ".md") then
      new_note_id = string.sub(new_note_id, 1, -4)
    end

    local new_note_path
    if #parts > 1 then
      parts[#parts] = nil
      new_note_path = vim.fs.joinpath(unpack(vim.tbl_flatten { tostring(client.dir), parts, new_note_id .. ".md" }))
    else
      new_note_path = vim.fs.joinpath(dirname, new_note_id .. ".md")
    end

    if new_note_id == cur_note_id then
      log.warn "New note ID is the same, doing nothing"
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
      log.warn "Rename canceled, doing nothing"
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
    quietly(vim.cmd.wall)

    -- Rename the note file and remove or rename the corresponding buffer, if there is one.
    if cur_note_bufnr ~= nil then
      if is_current_buf then
        -- If we're renaming the note of a current buffer, save as the new path.
        if not dry_run then
          quietly(vim.cmd.saveas, new_note_path)
          vim.fn.delete(cur_note_path)
        else
          log.info("Dry run: saving current buffer as '" .. new_note_path .. "' and removing old file")
        end
      else
        -- For the non-current buffer the best we can do is delete the buffer (we've already saved it above)
        -- and then make a file-system call to rename the file.
        if not dry_run then
          quietly(vim.cmd.bdelete, cur_note_bufnr)
          assert(vim.loop.fs_rename(cur_note_path, new_note_path)) ---@diagnostic disable-line: undefined-field
        else
          log.info("Dry run: removing buffer '" .. cur_note_path .. "' and renaming file to '" .. new_note_path .. "'")
        end
      end
    else
      -- When the note is not loaded into a buffer we just need to rename the file.
      if not dry_run then
        assert(vim.loop.fs_rename(cur_note_path, new_note_path)) ---@diagnostic disable-line: undefined-field
      else
        log.info("Dry run: renaming file '" .. cur_note_path .. "' to '" .. new_note_path .. "'")
      end
    end

    if not is_current_buf then
      -- When the note to rename is not the current buffer we need to update its frontmatter
      -- to account for the rename.
      cur_note.id = new_note_id
      cur_note.path = Path:new(new_note_path)
      if not dry_run then
        cur_note:save()
      else
        log.info("Dry run: updating frontmatter of '" .. new_note_path .. "'")
      end
    end

    local cur_note_rel_path = assert(client:vault_relative_path(cur_note_path))
    local new_note_rel_path = assert(client:vault_relative_path(new_note_path))

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
      for line_num, line in enumerate(f:lines(true)) do
        for ref, replacement in zip(reference_forms, replace_with) do
          local n
          line, n = util.string_replace(line, ref, replacement)
          if dry_run and n > 0 then
            log.info(
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

    search.search_async(
      client.dir,
      reference_forms,
      search.SearchOpts.from_tbl { fixed_strings = true, max_count_per_file = 1 },
      on_search_match,
      function(_)
        all_tasks_submitted = true
      end
    )

    -- Wait for all tasks to get submitted.
    vim.wait(2000, function()
      return all_tasks_submitted
    end, 50, false)

    -- Then block until all tasks are finished.
    executor:join(2000)

    local prefix = dry_run and "Dry run: replaced " or "Replaced "
    log.info(prefix .. replacement_count .. " reference(s) across " .. file_count .. " file(s)")

    -- In case the files of any current buffers were changed.
    vim.cmd.checktime()
  end,
})

M.register("ObsidianPasteImg", {
  opts = { nargs = "?", complete = "file" },
  ---@param client obsidian.Client
  func = function(client, data)
    local paste_img = require("obsidian.img_paste").paste_img

    local img_folder = Path:new(client.opts.attachments.img_folder)
    if not img_folder:is_absolute() then
      img_folder = client:vault_root() / client.opts.attachments.img_folder
    end

    local path = paste_img(data.args, img_folder)

    if path ~= nil then
      util.insert_text(client.opts.attachments.img_text_func(client, path))
    end
  end,
})

return M
