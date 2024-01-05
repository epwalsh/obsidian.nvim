local Note = require "obsidian.note"
local util = require "obsidian.util"
local iter = require("obsidian.itertools").iter

local command_lookups = {
  ObsidianCheck = "obsidian.commands.check",
  ObsidianToday = "obsidian.commands.today",
  ObsidianYesterday = "obsidian.commands.yesterday",
  ObsidianTomorrow = "obsidian.commands.tomorrow",
  ObsidianNew = "obsidian.commands.new",
  ObsidianOpen = "obsidian.commands.open",
  ObsidianBacklinks = "obsidian.commands.backlinks",
  ObsidianSearch = "obsidian.commands.search",
  ObsidianTemplate = "obsidian.commands.template",
  ObsidianQuickSwitch = "obsidian.commands.quick_switch",
  ObsidianLinkNew = "obsidian.commands.link_new",
  ObsidianLink = "obsidian.commands.link",
  ObsidianFollowLink = "obsidian.commands.follow_link",
  ObsidianWorkspace = "obsidian.commands.workspace",
  ObsidianRename = "obsidian.commands.rename",
  ObsidianPasteImg = "obsidian.commands.paste_img",
}

local M = setmetatable({
  commands = {},
}, {
  __index = function(t, k)
    local require_path = command_lookups[k]
    if not require_path then
      return
    end

    local mod = require(require_path)
    t[k] = mod

    return mod
  end,
})

---@class obsidian.CommandConfig
---@field opts table
---@field complete function|?
---@field func function|? (obsidian.Client, table) -> nil

---Register a new command.
---@param name string
---@param config obsidian.CommandConfig
M.register = function(name, config)
  if not config.func then
    config.func = function(client, data)
      return M[name](client, data)
    end
end
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
    local _, csrow, cscol, _ = unpack(assert(vim.fn.getpos "'<"))
    local _, cerow, cecol, _ = unpack(assert(vim.fn.getpos "'>"))
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
      local bufpath = vim.api.nvim_buf_get_name(assert(vim.fn.bufnr()))
      local note = Note.from_file(bufpath)
      note_id = tostring(note.id)
    end
    return { note_id }
  end
end

---Check the directory for notes with missing/invalid frontmatter.
M.register("ObsidianCheck", { opts = { nargs = 0 } })

---Create or open a new daily note.
M.register("ObsidianToday", { opts = { nargs = "?" } })

---Create (or open) the daily note from the last weekday.
M.register("ObsidianYesterday", { opts = { nargs = 0 } })

---Create (or open) the daily note for the next weekday.
M.register("ObsidianTomorrow", { opts = { nargs = 0 } })

---Create a new note.
M.register("ObsidianNew", { opts = { nargs = "?" } })

---Open a note in the Obsidian app.
M.register("ObsidianOpen", { opts = { nargs = "?" }, complete = M.complete_args_search })

---Get backlinks to a note.
M.register("ObsidianBacklinks", { opts = { nargs = 0 } })

---Search notes.
M.register("ObsidianSearch", { opts = { nargs = "?" } })

--- Insert a template
M.register("ObsidianTemplate", { opts = { nargs = "?" } })

---Quick switch to an obsidian note
M.register("ObsidianQuickSwitch", { opts = { nargs = 0 } })

---Create a new note and link to it.
M.register("ObsidianLinkNew", { opts = { nargs = "?", range = true } })

---Create a link to an existing note on the current visual selection.
M.register("ObsidianLink", { opts = { nargs = "?", range = true }, complete = M.complete_args_search })

---Follow link under cursor.
M.register("ObsidianFollowLink", { opts = { nargs = "?" } })

---Switch to a different workspace.
M.register("ObsidianWorkspace", { opts = { nargs = "?" } })

---Rename a note and update all backlinks.
M.register("ObsidianRename", { opts = { nargs = 1 }, complete = M.complete_args_id })

---Paste an image into a note.
M.register("ObsidianPasteImg", { opts = { nargs = "?", complete = "file" } })

return M
