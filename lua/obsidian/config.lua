local echo = require "obsidian.echo"
local workspace = require "obsidian.workspace"

local config = {}

---[[ Options specs ]]---

---@class obsidian.config.ClientOpts
---@field dir string|?
---@field workspaces obsidian.Workspace[]|?
---@field detect_cwd boolean
---@field log_level integer|?
---@field notes_subdir string|?
---@field templates obsidian.config.TemplateOpts
---@field note_id_func function|?
---@field follow_url_func function|?
---@field note_frontmatter_func function|?
---@field disable_frontmatter boolean|?
---@field backlinks obsidian.config.BacklinksOpts
---@field completion obsidian.config.CompletionOpts
---@field mappings obsidian.config.MappingOpts
---@field daily_notes obsidian.config.DailyNotesOpts
---@field use_advanced_uri boolean|?
---@field open_app_foreground boolean|?
---@field finder string|?
---@field sort_by string|?
---@field sort_reversed boolean|?
---@field open_notes_in "current"|"vsplit"|"hsplit"
---@field ui obsidian.config.UIOpts
---@field yaml_parser string|?
config.ClientOpts = {}

---Get defaults.
---@return obsidian.config.ClientOpts
config.ClientOpts.default = function()
  return {
    dir = nil,
    workspaces = {},
    detect_cwd = false,
    log_level = nil,
    notes_subdir = nil,
    templates = config.TemplateOpts.default(),
    note_id_func = nil,
    follow_url_func = nil,
    note_frontmatter_func = nil,
    disable_frontmatter = false,
    backlinks = config.BacklinksOpts.default(),
    completion = config.CompletionOpts.default(),
    mappings = config.MappingOpts.default(),
    daily_notes = config.DailyNotesOpts.default(),
    use_advanced_uri = nil,
    open_app_foreground = false,
    finder = nil,
    sort_by = "modified",
    sort_reversed = true,
    open_notes_in = "current",
    ui = config.UIOpts.default(),
    yaml_parser = "native",
  }
end

---Normalize options.
---
---@param opts table<string, any>
---@return obsidian.config.ClientOpts
config.ClientOpts.normalize = function(opts)
  ---@type obsidian.config.ClientOpts
  opts = vim.tbl_extend("force", config.ClientOpts.default(), opts)
  opts.backlinks = vim.tbl_extend("force", config.BacklinksOpts.default(), opts.backlinks)
  opts.completion = vim.tbl_extend("force", config.CompletionOpts.default(), opts.completion)
  opts.mappings = opts.mappings and opts.mappings or config.MappingOpts.default()
  opts.daily_notes = vim.tbl_extend("force", config.DailyNotesOpts.default(), opts.daily_notes)
  opts.templates = vim.tbl_extend("force", config.TemplateOpts.default(), opts.templates)
  opts.ui = vim.tbl_extend("force", config.UIOpts.default(), opts.ui)

  -- Validate.
  if opts.sort_by ~= nil and not vim.tbl_contains({ "path", "modified", "accessed", "created" }, opts.sort_by) then
    error("invalid 'sort_by' option '" .. opts.sort_by .. "'")
  end

  ---@diagnostic disable-next-line undefined-field
  if opts.overwrite_mappings ~= nil then
    echo.warn_once "the 'overwrite_mappings' config option is deprecated and no longer has any affect"
  end

  for key, value in pairs(opts.workspaces) do
    opts.workspaces[key].path = vim.fs.normalize(tostring(value.path))
  end

  if opts.dir ~= nil then
    -- NOTE: path will be normalized in workspace.new() fn
    table.insert(opts.workspaces, 1, workspace.new("dir", opts.dir))
  end

  return opts
end

---@class obsidian.config.BacklinksOpts
---@field height integer
---@field wrap boolean
config.BacklinksOpts = {}

---Get defaults.
---@return obsidian.config.BacklinksOpts
config.BacklinksOpts.default = function()
  return {
    height = 10,
    wrap = true,
  }
end

---@class obsidian.config.CompletionOpts
---@field nvim_cmp boolean
---@field min_chars integer
---@field new_notes_location "current_dir"|"notes_subdir"
---@field prepend_note_id boolean
config.CompletionOpts = {}

---Get defaults.
---@return obsidian.config.CompletionOpts
config.CompletionOpts.default = function()
  local has_nvim_cmp, _ = pcall(require, "cmp")
  return {
    nvim_cmp = has_nvim_cmp,
    min_chars = 2,
    new_notes_location = "current_dir",
    prepend_note_id = true,
  }
end

---@class obsidian.config.MappingOpts
config.MappingOpts = {}

---Get defaults.
---@return obsidian.config.MappingOpts
config.MappingOpts.default = function()
  return {
    ["gf"] = require("obsidian.mapping").gf_passthrough(),
    ["<leader>ch"] = require("obsidian.mapping").toggle_checkbox(),
  }
end

---@class obsidian.config.DailyNotesOpts
---@field folder string|?
---@field date_format string|?
---@field alias_format string|?
---@field template string|?
config.DailyNotesOpts = {}

---Get defaults.
---@return obsidian.config.DailyNotesOpts
config.DailyNotesOpts.default = function()
  return {
    folder = nil,
    date_format = nil,
    alias_format = nil,
  }
end

---@class obsidian.config.TemplateOpts
---@field subdir string
---@field date_format string|?
---@field time_format string|?
---@field substitutions table|?
config.TemplateOpts = {}

---Get defaults.
---@return obsidian.config.TemplateOpts
config.TemplateOpts.default = function()
  return {
    subdir = nil,
    date_format = nil,
    time_format = nil,
    substitutions = {},
  }
end

---@class obsidian.config.UIOpts
---@field enable boolean
---@field tick integer
---@field checkboxes table{string, obsidian.config.UICharSpec}
---@field external_link_icon obsidian.config.UICharSpec
---@field reference_text obsidian.config.UIStyleSpec
---@field hl_groups table{string, table}
config.UIOpts = {}

---@class obsidian.config.UICharSpec
---@field char string
---@field hl_group string

---@class obsidian.config.UIStyleSpec
---@field hl_group string

---@return obsidian.config.UIOpts
config.UIOpts.default = function()
  return {
    enable = true,
    tick = 200, -- TODO: 'update_debounce' would be a better name
    checkboxes = {
      [" "] = { char = "󰄱", hl_group = "ObsidianTodo" },
      ["x"] = { char = "", hl_group = "ObsidianDone" },
      [">"] = { char = "", hl_group = "ObsidianRightArrow" },
      ["~"] = { char = "󰰱", hl_group = "ObsidianTilde" },
    },
    external_link_icon = { char = "", hl_group = "ObsidianExtLinkIcon" },
    reference_text = { hl_group = "ObsidianRefText" },
    hl_groups = {
      ObsidianTodo = { bold = true, fg = "#f78c6c" },
      ObsidianDone = { bold = true, fg = "#89ddff" },
      ObsidianRightArrow = { bold = true, fg = "#f78c6c" },
      ObsidianTilde = { bold = true, fg = "#ff5370" },
      ObsidianRefText = { underline = true, fg = "#c792ea" },
      ObsidianExtLinkIcon = { fg = "#c792ea" },
    },
  }
end

return config
