local log = require "obsidian.log"
local workspace = require "obsidian.workspace"

local config = {}

---@class obsidian.config.ClientOpts
---@field dir string|?
---@field workspaces obsidian.Workspace[]|?
---@field detect_cwd boolean
---@field log_level integer
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
---@field sort_by obsidian.config.SortBy|?
---@field sort_reversed boolean|?
---@field open_notes_in obsidian.config.OpenStrategy
---@field ui obsidian.config.UIOpts
---@field attachments obsidian.config.AttachmentsOpts
---@field yaml_parser string|?
config.ClientOpts = {}

---@enum obsidian.config.OpenStrategy
config.OpenStrategy = {
  current = "current",
  vsplit = "vsplit",
  hsplit = "hsplit",
}

---Get defaults.
---@return obsidian.config.ClientOpts
config.ClientOpts.default = function()
  return {
    dir = nil,
    workspaces = {},
    detect_cwd = false,
    log_level = vim.log.levels.INFO,
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
    attachments = config.AttachmentsOpts.default(),
    yaml_parser = "native",
  }
end

---@enum obsidian.config.SortBy
config.SortBy = {
  path = "path",
  modified = "modified",
  accessed = "accessed",
  created = "created",
}

---Normalize options.
---
---@param opts table<string, any>
---@return obsidian.config.ClientOpts
config.ClientOpts.normalize = function(opts)
  local defaults = config.ClientOpts.default()
  ---@type obsidian.config.ClientOpts
  opts = vim.tbl_extend("force", defaults, opts)

  opts.backlinks = vim.tbl_extend("force", defaults.backlinks, opts.backlinks)
  opts.completion = vim.tbl_extend("force", defaults.completion, opts.completion)
  opts.mappings = opts.mappings and opts.mappings or defaults.mappings
  opts.daily_notes = vim.tbl_extend("force", defaults.daily_notes, opts.daily_notes)
  opts.templates = vim.tbl_extend("force", defaults.templates, opts.templates)
  opts.ui = vim.tbl_extend("force", defaults.ui, opts.ui)
  opts.attachments = vim.tbl_extend("force", defaults.attachments, opts.attachments)

  -- Rename old fields for backwards compatibility.
  if opts.ui.tick ~= nil then
    opts.ui.update_debounce = opts.ui.tick
    opts.ui.tick = nil
  end

  -- Validate.
  if opts.sort_by ~= nil and not vim.tbl_contains(vim.tbl_values(config.SortBy), opts.sort_by) then
    error("invalid 'sort_by' option '" .. opts.sort_by .. "'")
  end

  if
    not opts.completion.prepend_note_id
    and not opts.completion.prepend_note_path
    and not opts.completion.use_path_only
  then
    error "invalid 'completion' options"
  end

  -- Warn about deprecated fields.
  ---@diagnostic disable-next-line undefined-field
  if opts.overwrite_mappings ~= nil then
    log.warn_once "the 'overwrite_mappings' config option is deprecated and no longer has any affect"
    ---@diagnostic disable-next-line
    opts.overwrite_mappings = nil
  end

  -- Normalize workspace paths.
  for key, value in pairs(opts.workspaces) do
    opts.workspaces[key].path = vim.fs.normalize(tostring(value.path))
  end

  -- Convert dir to workspace format.
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
---@field prepend_note_path boolean
---@field use_path_only boolean
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
    prepend_note_path = false,
    use_path_only = false,
  }
end

---@class obsidian.config.MappingOpts
config.MappingOpts = {}

---Get defaults.
---@return obsidian.config.MappingOpts
config.MappingOpts.default = function()
  local mappings = require "obsidian.mappings"

  return {
    ["gf"] = mappings.gf_passthrough(),
    ["<leader>ch"] = mappings.toggle_checkbox(),
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
---@field substitutions table<string, function>|?
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
---@field update_debounce integer
---@field checkboxes table{string, obsidian.config.UICharSpec}
---@field external_link_icon obsidian.config.UICharSpec
---@field reference_text obsidian.config.UIStyleSpec
---@field highlight_text obsidian.config.UIStyleSpec
---@field tags obsidian.config.UIStyleSpec
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
    update_debounce = 200,
    checkboxes = {
      [" "] = { char = "󰄱", hl_group = "ObsidianTodo" },
      ["x"] = { char = "", hl_group = "ObsidianDone" },
      [">"] = { char = "", hl_group = "ObsidianRightArrow" },
      ["~"] = { char = "󰰱", hl_group = "ObsidianTilde" },
    },
    external_link_icon = { char = "", hl_group = "ObsidianExtLinkIcon" },
    reference_text = { hl_group = "ObsidianRefText" },
    highlight_text = { hl_group = "ObsidianHighlightText" },
    tags = { hl_group = "ObsidianTag" },
    hl_groups = {
      ObsidianTodo = { bold = true, fg = "#f78c6c" },
      ObsidianDone = { bold = true, fg = "#89ddff" },
      ObsidianRightArrow = { bold = true, fg = "#f78c6c" },
      ObsidianTilde = { bold = true, fg = "#ff5370" },
      ObsidianRefText = { underline = true, fg = "#c792ea" },
      ObsidianExtLinkIcon = { fg = "#c792ea" },
      ObsidianTag = { italic = true, fg = "#89ddff" },
      ObsidianHighlightText = { bg = "#75662e" },
    },
  }
end

---@class obsidian.config.AttachmentsOpts
---@field img_folder string Default folder to save images to, relative to the vault root.
---@field img_text_func function (obsidian.Client, Path,) -> string
config.AttachmentsOpts = {}

---@return obsidian.config.AttachmentsOpts
config.AttachmentsOpts.default = function()
  return {
    img_folder = "assets/imgs",
    ---@param client obsidian.Client
    ---@param path Path the absolute path to the image file
    ---@return string
    img_text_func = function(client, path)
      ---@type string
      local link_path
      local vault_relative_path = client:vault_relative_path(path)
      if vault_relative_path ~= nil then
        -- Use relative path if the image is saved in the vault dir.
        link_path = vault_relative_path
      else
        -- Otherwise use the absolute path.
        link_path = tostring(path)
      end
      local display_name = vim.fs.basename(link_path)
      return string.format("![%s](%s)", display_name, link_path)
    end,
  }
end

return config
