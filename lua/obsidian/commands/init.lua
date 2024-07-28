local util = require "obsidian.util"
local iter = require("obsidian.itertools").iter

local command_lookups = {
  ObsidianCheck = "obsidian.commands.check",
  ObsidianToggleCheckbox = "obsidian.commands.toggle_checkbox",
  ObsidianToday = "obsidian.commands.today",
  ObsidianYesterday = "obsidian.commands.yesterday",
  ObsidianTomorrow = "obsidian.commands.tomorrow",
  ObsidianDailies = "obsidian.commands.dailies",
  ObsidianNew = "obsidian.commands.new",
  ObsidianOpen = "obsidian.commands.open",
  ObsidianBacklinks = "obsidian.commands.backlinks",
  ObsidianSearch = "obsidian.commands.search",
  ObsidianTags = "obsidian.commands.tags",
  ObsidianTemplate = "obsidian.commands.template",
  ObsidianNewFromTemplate = "obsidian.commands.new_from_template",
  ObsidianQuickSwitch = "obsidian.commands.quick_switch",
  ObsidianLinkNew = "obsidian.commands.link_new",
  ObsidianLink = "obsidian.commands.link",
  ObsidianLinks = "obsidian.commands.links",
  ObsidianFollowLink = "obsidian.commands.follow_link",
  ObsidianWorkspace = "obsidian.commands.workspace",
  ObsidianRename = "obsidian.commands.rename",
  ObsidianPasteImg = "obsidian.commands.paste_img",
  ObsidianExtractNote = "obsidian.commands.extract_note",
  ObsidianDebug = "obsidian.commands.debug",
  ObsidianTOC = "obsidian.commands.toc",
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
  for note in iter(client:find_notes(query, { search = { sort = true } })) do
    local note_path = assert(client:vault_relative_path(note.path, { strict = true }))
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

M.register("ObsidianCheck", { opts = { nargs = 0, desc = "Check for issues in your vault" } })

M.register("ObsidianToday", { opts = { nargs = "?", desc = "Open today's daily note" } })

M.register("ObsidianYesterday", { opts = { nargs = 0, desc = "Open the daily note for the previous working day" } })

M.register("ObsidianTomorrow", { opts = { nargs = 0, desc = "Open the daily note for the next working day" } })

M.register("ObsidianDailies", { opts = { nargs = "*", desc = "Open a picker with daily notes" } })

M.register("ObsidianNew", { opts = { nargs = "?", complete = "file", desc = "Create a new note" } })

M.register(
  "ObsidianOpen",
  { opts = { nargs = "?", desc = "Open in the Obsidian app" }, complete = M.complete_args_search }
)

M.register("ObsidianBacklinks", { opts = { nargs = 0, desc = "Collect backlinks" } })

M.register("ObsidianTags", { opts = { nargs = "*", range = true, desc = "Find tags" } })

M.register("ObsidianSearch", { opts = { nargs = "?", desc = "Search vault" } })

M.register("ObsidianTemplate", { opts = { nargs = "?", desc = "Insert a template" } })

M.register("ObsidianNewFromTemplate", { opts = { nargs = "?", desc = "Create a new note from a template" } })

M.register("ObsidianQuickSwitch", { opts = { nargs = "?", desc = "Switch notes" } })

M.register("ObsidianLinkNew", { opts = { nargs = "?", range = true, desc = "Link selected text to a new note" } })

M.register("ObsidianLink", {
  opts = { nargs = "?", range = true, desc = "Link selected text to an existing note" },
  complete = M.complete_args_search,
})

M.register("ObsidianLinks", { opts = { nargs = 0, desc = "Collect all links within the current buffer" } })

M.register("ObsidianFollowLink", { opts = { nargs = "?", desc = "Follow reference or link under cursor" } })

M.register("ObsidianToggleCheckbox", { opts = { nargs = 0, desc = "Toggle checkbox" } })

M.register("ObsidianWorkspace", { opts = { nargs = "?", desc = "Check or switch workspace" } })

M.register(
  "ObsidianRename",
  { opts = { nargs = "?", complete = "file", desc = "Rename note and update all references to it" } }
)

M.register(
  "ObsidianPasteImg",
  { opts = { nargs = "?", complete = "file", desc = "Paste an image from the clipboard" } }
)

M.register(
  "ObsidianExtractNote",
  { opts = { nargs = "?", range = true, desc = "Extract selected text to a new note and link to it" } }
)

M.register("ObsidianDebug", { opts = { nargs = 0, desc = "Log some information for debugging" } })

M.register("ObsidianTOC", { opts = { nargs = 0, desc = "Load the table of contents into a picker" } })

return M
