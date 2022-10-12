local Path = require "plenary.path"
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
    path = Path:new(data.args):make_relative(vault)
  else
    local bufname = vim.api.nvim_buf_get_name(0)
    path = Path:new(bufname):make_relative(vault)
  end

  local encoded_vault = util.urlencode(vault_name)
  local encoded_path = util.urlencode(tostring(path))
  local cmd = nil
  local sysname = vim.loop.os_uname().sysname
  if sysname == "Linux" then
    cmd = ("xdg-open 'obsidian://open?vault=%s&file=%s'"):format(encoded_vault, encoded_path)
  elseif sysname == "Darwin" then
    cmd = ("open -a /Applications/Obsidian.app --background 'obsidian://open?vault=%s&file=%s'"):format(
      encoded_vault,
      encoded_path
    )
  else
    echo.err "open command does not support this OS yet"
  end

  if cmd ~= nil then
    local return_code = os.execute(cmd)
    if return_code > 0 then
      echo.err "failed opening Obsidian app to note"
    end
  end
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
  local base_cmd = vim.tbl_flatten { util.SEARCH_CMD, { "--column", "--line-number", "--no-heading" } }

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
    echo.err "Either telescope.nvim or fzf.vim is required for :ObsidianSearch command"
  end
end

local commands = {
  ObsidianCheck = { func = command.check, opts = { nargs = 0 } },
  ObsidianToday = { func = command.today, opts = { nargs = 0 } },
  ObsidianOpen = { func = command.open, opts = { nargs = "?" } },
  ObsidianNew = { func = command.new, opts = { nargs = "?" } },
  ObsidianBacklinks = { func = command.backlinks, opts = { nargs = 0 } },
  ObsidianSearch = { func = command.search, opts = { nargs = "?" } },
}

---Register all commands.
---
---@param client obsidian.Client
command.register_all = function(client)
  for command_name, command_config in pairs(commands) do
    local func = function(data)
      command_config.func(client, data)
    end
    vim.api.nvim_create_user_command(command_name, func, command_config.opts)
  end
end

return command
