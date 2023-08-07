local Path = require "plenary.path"
local Job = require "plenary.job"
local Note = require "obsidian.note"
local echo = require "obsidian.echo"
local util = require "obsidian.util"

local command = {}

---Check the directory for notes with missing/invalid frontmatter.
---
---@param client obsidian.Client
---@param _ table
command.check = function(client, _)
  local scan = require "plenary.scandir"

  local count = 0
  local err_count = 0
  local warn_count = 0

  scan.scan_dir(vim.fs.normalize(tostring(client.dir)), {
    hidden = false,
    add_dirs = false,
    respect_gitignore = true,
    search_pattern = ".*%.md",
    on_insert = function(entry)
      count = count + 1
      Note.from_file(entry, client.dir)
      local ok, note = pcall(Note.from_file, entry, client.dir)
      if not ok then
        err_count = err_count + 1
        echo.err("Failed to parse note at " .. entry, client.opts.log_level)
      elseif note.has_frontmatter == false then
        warn_count = warn_count + 1
        echo.warn(tostring(entry) .. " is missing frontmatter", client.opts.log_level)
      end
    end,
  })

  echo.info("Found " .. tostring(count) .. " notes total", client.opts.log_level)
  if warn_count > 0 then
    echo.warn("There were " .. tostring(warn_count) .. " warnings", client.opts.log_level)
  end
  if err_count > 0 then
    echo.err("There were " .. tostring(err_count) .. " errors", client.opts.log_level)
  end
end

---Create a new daily note.
---
---@param client obsidian.Client
---@param _ table
command.today = function(client, _)
  local note = client:today()
  local open_in = util.get_open_strategy(client.opts.open_notes_in)
  vim.api.nvim_command(open_in .. tostring(note.path))
end

---Create (or open) the daily note from the last weekday.
---
---@param client obsidian.Client
---@param _ table
command.yesterday = function(client, _)
  local note = client:yesterday()
  local open_in = util.get_open_strategy(client.opts.open_notes_in)
  vim.api.nvim_command(open_in .. tostring(note.path))
end

---Create a new note.
---
---@param client obsidian.Client
---@param data table
command.new = function(client, data)
  ---@type obsidian.Note
  local note
  local open_in = util.get_open_strategy(client.opts.open_notes_in)
  if data.args:len() > 0 then
    note = client:new_note(data.args)
  else
    note = client:new_note()
  end
  vim.api.nvim_command(open_in .. tostring(note.path))
end

---Open a note in the Obsidian app.
---
---@param client obsidian.Client
---@param data table
command.open = function(client, data)
  local vault = client:vault()
  if vault == nil then
    echo.err("couldn't find an Obsidian vault", client.opts.log_level)
    return
  end
  local vault_name = vim.fs.basename(vault)

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
  if sysname == "Linux" then
    cmd = "xdg-open"
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

  Job:new({
    command = cmd,
    args = args,
    on_exit = vim.schedule_wrap(function(_, return_code)
      if return_code > 0 then
        echo.err("failed opening Obsidian app to note", client.opts.log_level)
      end
    end),
  }):start()
end

---Get backlinks to a note.
---
---@param client obsidian.Client
command.backlinks = function(client, _)
  local ok, backlinks = pcall(function()
    return require("obsidian.backlinks").new(client)
  end)
  if ok then
    echo.info(
      ("Showing backlinks '%s'. Hit ENTER on a line to follow the backlink."):format(backlinks.note.id),
      client.opts.log_level
    )
    backlinks:view()
  else
    echo.err("Backlinks command can only be used from a valid note", client.opts.log_level)
  end
end

---Search notes.
---
---@param client obsidian.Client
---@param data table
command.search = function(client, data)
  local base_cmd = vim.tbl_flatten { util.SEARCH_CMD, { "--smart-case", "--column", "--line-number", "--no-heading" } }

  client:_run_with_finder_backend(":ObsidianSearch", {
    ["telescope.nvim"] = function()
      local has_telescope, telescope = pcall(require, "telescope.builtin")

      if not has_telescope then
        util.implementation_unavailable()
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
    end,
    ["fzf-lua"] = function()
      local has_fzf_lua, fzf_lua = pcall(require, "fzf-lua")

      if not has_fzf_lua then
        util.implementation_unavailable()
      end
      if data.args:len() > 0 then
        fzf_lua.grep { cwd = tostring(client.dir), search = data.args }
      else
        fzf_lua.live_grep { cwd = tostring(client.dir), exec_empty_query = true }
      end
    end,
    ["fzf.vim"] = function()
      -- Fall back to trying with fzf.vim
      local has_fzf, _ = pcall(function()
        local grep_cmd = vim.tbl_flatten {
          base_cmd,
          {
            "--color=always",
            "--",
            vim.fn.shellescape(data.args),
            tostring(client.dir),
          },
        }

        vim.api.nvim_call_function("fzf#vim#grep", {
          table.concat(grep_cmd, " "),
          true,
          vim.api.nvim_call_function("fzf#vim#with_preview", {}),
          false,
        })
      end)
      if not has_fzf then
        util.implementation_unavailable()
      end
    end,
  })
end

--- Insert a template
---
---@param client obsidian.Client
---@param data table
command.template = function(client, data)
  if not client.opts.templates.subdir then
    echo.err("No templates folder defined in setup()", client.opts.log_level)
    return
  end

  local templates_dir = client.templates_dir

  -- We need to get this upfront before
  -- Telescope hijacks the current window
  local insert_location = util.get_active_window_cursor_location()

  local function insert_template(name)
    util.insert_template(name, client, insert_location)
  end

  if string.len(data.args) > 0 then
    local template_name = data.args
    local path = Path:new(templates_dir) / template_name
    if path:is_file() then
      insert_template(data.args)
    else
      echo.err("Not a valid template file", client.opts.log_level)
    end
    return
  end

  client:_run_with_finder_backend(":ObsidianTemplate", {
    ["telescope.nvim"] = function()
      -- try with telescope.nvim
      local has_telescope, _ = pcall(require, "telescope.builtin")
      if not has_telescope then
        util.implementation_unavailable()
      end
      local choose_template = function()
        local opts = {
          cwd = tostring(templates_dir),
          attach_mappings = function(_, map)
            map({ "i", "n" }, "<CR>", function(prompt_bufnr)
              local template = require("telescope.actions.state").get_selected_entry()
              require("telescope.actions").close(prompt_bufnr)
              insert_template(template[1])
            end)
            return true
          end,
        }
        require("telescope.builtin").find_files(opts)
      end
      choose_template()
    end,
    ["fzf-lua"] = function()
      -- try with fzf-lua
      local has_fzf_lua, fzf_lua = pcall(require, "fzf-lua")
      if not has_fzf_lua then
        util.implementation_unavailable()
      end
      local cmd = vim.tbl_flatten { util.FIND_CMD, { ".", "-name", "'*.md'" } }
      cmd = util.table_params_to_str(cmd)
      fzf_lua.files {
        cmd = cmd,
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
    end,
    ["fzf.vim"] = function()
      -- try with fzf
      local has_fzf, _ = pcall(function()
        vim.api.nvim_create_user_command("ApplyTemplate", function(path)
          -- remove escaped whitespace and extract the file name
          local file_path = string.gsub(path.args, "\\ ", " ")
          local template = vim.fs.basename(file_path)
          insert_template(template)
          vim.api.nvim_del_user_command "ApplyTemplate"
        end, { nargs = 1, bang = true })

        local base_cmd = vim.tbl_flatten { util.FIND_CMD, { tostring(templates_dir), "-name", "'*.md'" } }
        base_cmd = util.table_params_to_str(base_cmd)
        local fzf_options = { source = base_cmd, sink = "ApplyTemplate" }
        vim.api.nvim_call_function("fzf#run", {
          vim.api.nvim_call_function("fzf#wrap", { fzf_options }),
        })
      end)
      if not has_fzf then
        util.implementation_unavailable()
      end
    end,
  })
end

---Quick switch to an obsidian note
---
---@param client obsidian.Client
---@param data table
command.quick_switch = function(client, data)
  local dir = tostring(client.dir)

  client:_run_with_finder_backend(":ObsidianQuickSwitch", {
    ["telescope.nvim"] = function()
      local has_telescope, telescope = pcall(require, "telescope.builtin")

      if not has_telescope then
        util.implementation_unavailable()
      end
      -- Search with telescope.nvim
      telescope.find_files { cwd = dir, search_file = "*.md" }
    end,
    ["fzf-lua"] = function()
      local has_fzf_lua, fzf_lua = pcall(require, "fzf-lua")

      if not has_fzf_lua then
        util.implementation_unavailable()
      end
      local cmd = vim.tbl_flatten { util.FIND_CMD, { ".", "-name", "'*.md'" } }
      cmd = util.table_params_to_str(cmd)
      fzf_lua.files { cmd = cmd, cwd = tostring(client.dir) }
    end,
    ["fzf.vim"] = function()
      -- Fall back to trying with fzf.vim
      local has_fzf, _ = pcall(function()
        local base_cmd = vim.tbl_flatten { util.FIND_CMD, { dir, "-name", "'*.md'" } }
        base_cmd = util.table_params_to_str(base_cmd)
        local fzf_options = { source = base_cmd, sink = "e" }
        vim.api.nvim_call_function("fzf#run", {
          vim.api.nvim_call_function("fzf#wrap", { fzf_options }),
        })
      end)
      if not has_fzf then
        util.implementation_unavailable()
      end
    end,
  })
end

command.link_new = function(client, data)
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
    .. note.id
    .. "|"
    .. string.sub(line, cscol, cecol)
    .. "]]"
    .. string.sub(line, cecol + 1)
  vim.api.nvim_buf_set_lines(0, csrow - 1, csrow, false, { line })
end

command.link = function(client, data)
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
    .. note.id
    .. "|"
    .. string.sub(line, cscol, cecol)
    .. "]]"
    .. string.sub(line, cecol + 1)
  vim.api.nvim_buf_set_lines(0, csrow - 1, csrow, false, { line })
end

command.complete_args = function(client, _, cmd_line, _)
  local search
  local cmd_arg, _ = util.strip(string.gsub(cmd_line, "^.*Obsidian[A-Za-z0-9]+", ""))
  if string.len(cmd_arg) > 0 then
    if string.find(cmd_arg, "|", 1, true) then
      return {}
    else
      search = cmd_arg
    end
  else
    local _, csrow, cscol, _ = unpack(vim.fn.getpos "'<")
    local _, cerow, cecol, _ = unpack(vim.fn.getpos "'>")
    local lines = vim.fn.getline(csrow, cerow)

    if #lines > 1 then
      lines[1] = string.sub(lines[1], cscol)
      lines[#lines] = string.sub(lines[#lines], 1, cecol)
    elseif #lines == 1 then
      lines[1] = string.sub(lines[1], cscol, cecol)
    else
      return {}
    end

    search = table.concat(lines, " ")
  end

  local completions = {}
  local search_lwr = string.lower(search)
  for note in client:search(search) do
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

---Follow link under cursor.
---
---@param client obsidian.Client
command.follow = function(client, _)
  local open, close = util.cursor_on_markdown_link()
  local current_line = vim.api.nvim_get_current_line()

  if open == nil or close == nil then
    echo.err("Cursor is not on a reference!", client.opts.log_level)
    return
  end

  local note_name = current_line:sub(open, close)
  if note_name:match "^%[.-%]%(.*%)$" then
    -- transform markdown link to wiki link
    note_name = note_name:gsub("^%[(.-)%]%((.*)%)$", "%2|%1")
  else
    -- wiki link
    note_name = note_name:sub(3, #note_name - 2)
  end

  -- Split note file name/path from note name/alias.
  local note_file_name = note_name
  if note_name:match "|[^%]]*" then
    note_file_name = note_file_name:sub(1, note_file_name:find "|" - 1)
    note_name = note_name:sub(note_name:find "|" + 1, note_name:len())
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

  -- Remove header link from the end if there is one.
  local header_link = note_file_name:match "#[%a%d-_]+$"
  if header_link ~= nil then
    note_file_name = note_file_name:sub(1, -header_link:len() - 1)
  end

  -- Ensure file name ends with suffix.
  if not note_file_name:match "%.md" then
    note_file_name = note_file_name .. ".md"
  end

  -- Search for matching notes.
  local notes = util.find_note(client.dir, note_file_name)

  if #notes < 1 then
    local aliases = note_name == note_file_name and {} or { note_name }
    local note = client:new_note(note_file_name, nil, nil, aliases)
    vim.api.nvim_command("e " .. tostring(note.path))
  elseif #notes == 1 then
    local path = notes[1]
    vim.api.nvim_command("e " .. tostring(path))
  else
    echo.err("Multiple notes with this name exist", client.opts.log_level)
    return
  end
end

---Run a health check.
---
---@param client obsidian.Client
command.check_health = function(client, _)
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
end

local commands = {
  ObsidianCheck = { func = command.check, opts = { nargs = 0 } },
  ObsidianTemplate = { func = command.template, opts = { nargs = "?" } },
  ObsidianToday = { func = command.today, opts = { nargs = 0 } },
  ObsidianYesterday = { func = command.yesterday, opts = { nargs = 0 } },
  ObsidianOpen = { func = command.open, opts = { nargs = "?" }, complete = command.complete_args },
  ObsidianNew = { func = command.new, opts = { nargs = "?" } },
  ObsidianQuickSwitch = { func = command.quick_switch, opts = { nargs = 0 } },
  ObsidianBacklinks = { func = command.backlinks, opts = { nargs = 0 } },
  ObsidianSearch = { func = command.search, opts = { nargs = "?" } },
  ObsidianLink = { func = command.link, opts = { nargs = "?", range = true }, complete = command.complete_args },
  ObsidianLinkNew = { func = command.link_new, opts = { nargs = "?", range = true } },
  ObsidianFollowLink = { func = command.follow, opts = { nargs = 0 } },
  ObsidianCheckHealth = { func = command.check_health, opts = { nargs = 0 } },
}

---Register all commands.
---
---@param client obsidian.Client
command.register_all = function(client)
  for command_name, command_config in pairs(commands) do
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

return command
