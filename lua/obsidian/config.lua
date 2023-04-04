local config = {}

---[[ Options specs ]]---

---@class obsidian.config.ClientOpts
---@field dir string
---@field notes_subdir string|?
---@field templates table|?
---@field templates.subdir string
---@field templates.date_format string
---@field templates.time_format string
---@field note_id_func function|?
---@field note_frontmatter_func function|?
---@field disable_frontmatter boolean|?
---@field completion obsidian.config.CompletionOpts
---@field daily_notes obsidian.config.DailyNotesOpts
---@field use_advanced_uri boolean|?
---@field open_app_foreground boolean|?
config.ClientOpts = {}

---Get defaults.
---@return obsidian.config.ClientOpts
config.ClientOpts.default = function()
  return {
    dir = vim.fs.normalize "./",
    notes_subdir = nil,
    templates = nil,
    note_id_func = nil,
    note_frontmatter_func = nil,
    disable_frontmatter = false,
    completion = config.CompletionOpts.default(),
    daily_notes = config.DailyNotesOpts.default(),
    use_advanced_uri = nil,
    open_app_foreground = false,
  }
end

---Normalize options.
---
---@param opts table<string, any>
---@return obsidian.config.ClientOpts
config.ClientOpts.normalize = function(opts)
  opts = vim.tbl_extend("force", config.ClientOpts.default(), opts)
  opts.completion = vim.tbl_extend("force", config.CompletionOpts.default(), opts.completion)
  opts.daily_notes = vim.tbl_extend("force", config.DailyNotesOpts.default(), opts.daily_notes)
  opts.dir = vim.fs.normalize(tostring(opts.dir))
  return opts
end

---@class obsidian.config.CompletionOpts
---@field nvim_cmp boolean
---@field min_chars integer
config.CompletionOpts = {}

---Get defaults.
---@return obsidian.config.CompletionOpts
config.CompletionOpts.default = function()
  local has_nvim_cmp, _ = pcall(require, "cmp")
  return {
    nvim_cmp = has_nvim_cmp,
    min_chars = 2,
  }
end

---@class obsidian.config.DailyNotesOpts
---@field folder string|?
config.DailyNotesOpts = {}

---Get defaults.
---@return obsidian.config.DailyNotesOpts
config.DailyNotesOpts.default = function()
  return {
    folder = nil,
  }
end

return config
