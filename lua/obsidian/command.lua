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
        echo.err("Failed to parse note at " .. entry)
      elseif note.has_frontmatter == false then
        warn_count = warn_count + 1
        echo.warn(tostring(entry) .. " is missing frontmatter")
      end
    end,
  })

  echo.info("Found " .. tostring(count) .. " notes total")
  if warn_count > 0 then
    echo.warn("There were " .. tostring(warn_count) .. " warnings")
  end
  if err_count > 0 then
    echo.err("There were " .. tostring(err_count) .. " errors")
  end
end

---Create a new daily note.
---
---@param client obsidian.Client
---@param _ table
command.today = function(client, _)
  local note = client:today()
  vim.api.nvim_command("e " .. tostring(note.path))
end

---Create (or open) the daily note from the last weekday.
---
---@param client obsidian.Client
---@param _ table
command.yesterday = function(client, _)
  local note = client:yesterday()
  vim.api.nvim_command("e " .. tostring(note.path))
end

---Create a new note.
---
---@param client obsidian.Client
---@param data table
command.new = function(client, data)
  ---@type obsidian.Note
  local note
  if data.args:len() > 0 then
    note = client:new_note(data.args)
  else
    note = client:new_note()
  end
  vim.api.nvim_command("e " .. tostring(note.path))
end

---Open a note in the Obsidian app.
---
---@param client obsidian.Client
---@param data table
command.open = function(client, data)
  local vault = client:vault()
  if vault == nil then
    echo.err "couldn't find an Obsidian vault"
    return
  end
  local vault_name = vim.fs.basename(vault)

  local path
  if data.args:len() > 0 then
    local note = client:resolve_note(data.args)
    if note ~= nil then
      path = note.path:make_relative(vault)
    else
      echo.err "Could not resolve arguments to a note ID, path, or alias"
      return
    end
  else
    local bufname = vim.api.nvim_buf_get_name(0)
    path = Path:new(bufname):make_relative(vault)
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
    args = { "-a", "/Applications/Obsidian.app", "--background", uri }
  end

  if cmd == nil then
    echo.err "open command does not support this OS yet"
    return
  end

  Job:new({
    command = cmd,
    args = args,
    on_exit = vim.schedule_wrap(function(_, return_code)
      if return_code > 0 then
        echo.err "failed opening Obsidian app to note"
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
    echo.info(("Showing backlinks '%s'. Hit ENTER on a line to follow the backlink."):format(backlinks.note.id))
    backlinks:view()
  else
    echo.err "Backlinks command can only be used from a valid note"
  end
end

---Search notes.
---
---@param client obsidian.Client
---@param data table
command.search = function(client, data)
  local base_cmd = vim.tbl_flatten { util.SEARCH_CMD, { "--smart-case", "--column", "--line-number", "--no-heading" } }

  local has_telescope, telescope = pcall(require, "telescope.builtin")

  if has_telescope then
    -- Search with telescope.nvim
    local vimgrep_arguments = vim.tbl_flatten { base_cmd, {
      "--with-filename",
      "--color=never",
    } }

    if data.args:len() > 0 then
      telescope.grep_string { cwd = tostring(client.dir), search = data.args, vimgrep_arguments = vimgrep_arguments }
    else
      telescope.live_grep { cwd = tostring(client.dir), vimgrep_arguments = vimgrep_arguments }
    end
    return
  end

  local has_fzf_lua, fzf_lua = pcall(require, "fzf-lua")

  if has_fzf_lua then
    if data.args:len() > 0 then
      fzf_lua.grep { cwd = tostring(client.dir), search = data.args }
    else
      fzf_lua.live_grep { cwd = tostring(client.dir), exec_empty_query = true }
    end
    return
  end

  -- Fall back to trying with fzf.vim
  local has_fzf, _ = pcall(function()
    local grep_cmd =
      vim.tbl_flatten { base_cmd, { "--color=always", "--", vim.fn.shellescape(data.args), tostring(client.dir) } }

    vim.api.nvim_call_function("fzf#vim#grep", {
      table.concat(grep_cmd, " "),
      true,
      vim.api.nvim_call_function("fzf#vim#with_preview", {}),
      false,
    })
  end)

  if not has_fzf then
    echo.err "Either telescope.nvim, fzf-lua or fzf.vim is required for :ObsidianSearch command"
  end
end

---Quick switch to an obsidian note
---
---@param client obsidian.Client
---@param data table
command.quick_switch = function(client, data)
  local dir = tostring(client.dir)
  local has_telescope, telescope = pcall(require, "telescope.builtin")

  if has_telescope then
    -- Search with telescope.nvim
    telescope.find_files { cwd = dir, search_file = "*.md" }
    return
  end

  local has_fzf_lua, fzf_lua = pcall(require, "fzf-lua")

  if has_fzf_lua then
    local cmd = vim.tbl_flatten { util.FIND_CMD, { ".", "-name", "'*.md'" } }
    cmd = util.table_params_to_str(cmd)
    fzf_lua.files { cmd = cmd, cwd = tostring(client.dir) }
    return
  end

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
    echo.err "Either telescope.nvim or fzf.vim is required for :ObsidianQuickSwitch command"
  end
end

command.link_new = function(client, data)
  local _, csrow, cscol, _ = unpack(vim.fn.getpos "'<")
  local _, cerow, cecol, _ = unpack(vim.fn.getpos "'>")

  if data.line1 ~= csrow or data.line2 ~= cerow then
    echo.err "ObsidianLink must be called with visual selection"
    return
  end

  local lines = vim.fn.getline(csrow, cerow)
  if #lines ~= 1 then
    echo.err "Only in-line visual selections allowed"
    return
  end

  local line = lines[1]

  local title
  if string.len(data.args) > 0 then
    title = data.args
  else
    title = string.sub(line, cscol, cecol)
  end
  local note = client:new_note(title)

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
    echo.err "ObsidianLink must be called with visual selection"
    return
  end

  local lines = vim.fn.getline(csrow, cerow)
  if #lines ~= 1 then
    echo.err "Only in-line visual selections allowed"
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
    echo.err "Could not resolve argument to a note ID, alias, or path"
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
    echo.err "Cursor is not on a reference!"
    return
  end

  local note_name = current_line:sub(open + 2, close - 1)
  local note_file_name = note_name

  if note_file_name:match "|[^%]]*" then
    note_file_name = note_file_name:sub(1, note_file_name:find "|" - 1)
  end

  if not note_file_name:match "%.md" then
    note_file_name = note_file_name .. ".md"
  end

  local notes = util.find_note(client.dir, note_file_name)

  if #notes < 1 then
    command.new(client, { args = note_name })
  elseif #notes == 1 then
    local path = notes[1]
    vim.api.nvim_command("e " .. tostring(path))
  else
    echo.err "Multiple notes with this name exist"
    return
  end
end

local commands = {
  ObsidianCheck = { func = command.check, opts = { nargs = 0 } },
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
