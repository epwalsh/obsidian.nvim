local config = {}

---[[ Options specs ]]---

---@class obsidian.config.ClientOpts
---@field dir string
---@field log_level integer|?
---@field notes_subdir string|?
---@field templates table|?
---@field templates.subdir string
---@field templates.date_format string
---@field templates.time_format string
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
---@field open_notes_in "current"|"vsplit"|"hsplit"
config.ClientOpts = {}

---Get defaults.
---@return obsidian.config.ClientOpts
config.ClientOpts.default = function()
  return {
    dir = vim.fs.normalize "./",
    log_level = nil,
    notes_subdir = nil,
    templates = nil,
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
    open_notes_in = "current",
  }
end

---Normalize options.
---
---@param opts table<string, any>
---@return obsidian.config.ClientOpts
config.ClientOpts.normalize = function(opts)
  opts = vim.tbl_extend("force", config.ClientOpts.default(), opts)
  opts.backlinks = vim.tbl_extend("force", config.BacklinksOpts.default(), opts.backlinks)
  opts.completion = vim.tbl_extend("force", config.CompletionOpts.default(), opts.completion)
  opts.mappings = opts.mappings and opts.mappings or config.MappingOpts.default()
  opts.daily_notes = vim.tbl_extend("force", config.DailyNotesOpts.default(), opts.daily_notes)
  opts.dir = vim.fs.normalize(tostring(opts.dir))
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
  }
end

---@class obsidian.config.DailyNotesOpts
---@field folder string|?
---@field date_format string|?
config.DailyNotesOpts = {}

---Get defaults.
---@return obsidian.config.DailyNotesOpts
config.DailyNotesOpts.default = function()
  return {
    folder = nil,
    date_format = nil,
  }
end

return config
