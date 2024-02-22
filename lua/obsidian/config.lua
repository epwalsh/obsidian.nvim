local log = require "obsidian.log"
local util = require "obsidian.util"

local config = {}

---@class obsidian.config.ClientOpts
---@field dir string|?
---@field workspaces obsidian.workspace.WorkspaceSpec[]|?
---@field log_level integer
---@field notes_subdir string|?
---@field templates obsidian.config.TemplateOpts
---@field new_notes_location obsidian.config.NewNotesLocation
---@field note_id_func (fun(title: string|?): string)|?
---@field wiki_link_func (fun(opts: {path: string, label: string, id: string|?}): string)
---@field markdown_link_func (fun(opts: {path: string, label: string, id: string|?}): string)
---@field preferred_link_style obsidian.config.LinkStyle
---@field follow_url_func fun(url: string)|?
---@field image_name_func (fun(): string)|?
---@field note_frontmatter_func fun(note: obsidian.Note)|?
---@field disable_frontmatter (fun(fname: string?): boolean)|boolean|?
---@field completion obsidian.config.CompletionOpts
---@field mappings obsidian.config.MappingOpts
---@field picker obsidian.config.PickerOpts
---@field daily_notes obsidian.config.DailyNotesOpts
---@field use_advanced_uri boolean|?
---@field open_app_foreground boolean|?
---@field sort_by obsidian.config.SortBy|?
---@field sort_reversed boolean|?
---@field open_notes_in obsidian.config.OpenStrategy
---@field ui obsidian.config.UIOpts
---@field attachments obsidian.config.AttachmentsOpts
---@field yaml_parser string|?
config.ClientOpts = {}

--- Get defaults.
---
---@return obsidian.config.ClientOpts
config.ClientOpts.default = function()
  return {
    dir = nil,
    workspaces = {},
    log_level = vim.log.levels.INFO,
    notes_subdir = nil,
    new_notes_location = config.NewNotesLocation.current_dir,
    templates = config.TemplateOpts.default(),
    note_id_func = nil,
    wiki_link_func = util.wiki_link_id_prefix,
    markdown_link_func = util.markdown_link,
    preferred_link_style = config.LinkStyle.wiki,
    follow_url_func = nil,
    note_frontmatter_func = nil,
    disable_frontmatter = false,
    completion = config.CompletionOpts.default(),
    mappings = config.MappingOpts.default(),
    picker = config.PickerOpts.default(),
    daily_notes = config.DailyNotesOpts.default(),
    use_advanced_uri = nil,
    open_app_foreground = false,
    sort_by = "modified",
    sort_reversed = true,
    open_notes_in = "current",
    ui = config.UIOpts.default(),
    attachments = config.AttachmentsOpts.default(),
    yaml_parser = "native",
  }
end

local tbl_override = function(defaults, overrides)
  local out = vim.tbl_extend("force", defaults, overrides)
  for k, v in pairs(out) do
    if v == vim.NIL then
      out[k] = nil
    end
  end
  return out
end

--- Normalize options.
---
---@param opts table<string, any>
---@param defaults obsidian.config.ClientOpts|?
---
---@return obsidian.config.ClientOpts
config.ClientOpts.normalize = function(opts, defaults)
  if not defaults then
    defaults = config.ClientOpts.default()
  end

  -------------------------------------------------------------------------------------
  -- Rename old fields for backwards compatibility and warn about deprecated fields. --
  -------------------------------------------------------------------------------------

  if opts.ui and opts.ui.tick then
    opts.ui.update_debounce = opts.ui.tick
    opts.ui.tick = nil
  end

  if not opts.picker then
    opts.picker = {}
    if opts.finder then
      opts.picker.name = opts.finder
      opts.finder = nil
    end
    if opts.finder_mappings then
      opts.picker.mappings = opts.finder_mappings
      opts.finder_mappings = nil
    end
  end

  if opts.wiki_link_func == nil and opts.completion ~= nil then
    local warn = false

    if opts.completion.prepend_note_id then
      opts.wiki_link_func = util.wiki_link_id_prefix
      opts.completion.prepend_note_id = nil
      warn = true
    elseif opts.completion.prepend_note_path then
      opts.wiki_link_func = util.wiki_link_path_prefix
      opts.completion.prepend_note_path = nil
      warn = true
    elseif opts.completion.use_path_only then
      opts.wiki_link_func = util.wiki_link_path_only
      opts.completion.use_path_only = nil
      warn = true
    end

    if warn then
      log.warn_once(
        "The config options 'completion.prepend_note_id', 'completion.prepend_note_path', and 'completion.use_path_only' "
          .. "are deprecated. Please use 'wiki_link_func' instead.\n"
          .. "See https://github.com/epwalsh/obsidian.nvim/pull/406"
      )
    end
  end

  if opts.completion ~= nil and opts.completion.preferred_link_style ~= nil then
    opts.preferred_link_style = opts.completion.preferred_link_style
    opts.completion.preferred_link_style = nil
    log.warn_once(
      "The config option 'completion.preferred_link_style' is deprecated, please use the top-level "
        .. "'preferred_link_style' instead."
    )
  end

  if opts.completion ~= nil and opts.completion.new_notes_location ~= nil then
    opts.new_notes_location = opts.completion.new_notes_location
    opts.completion.new_notes_location = nil
    log.warn_once(
      "The config option 'completion.new_notes_location' is deprecated, please use the top-level "
        .. "'new_notes_location' instead."
    )
  end

  if opts.detect_cwd ~= nil then
    opts.detect_cwd = nil
    log.warn_once(
      "The 'detect_cwd' field is deprecated and no longer has any affect.\n"
        .. "See https://github.com/epwalsh/obsidian.nvim/pull/366 for more details."
    )
  end

  if opts.overwrite_mappings ~= nil then
    log.warn_once "The 'overwrite_mappings' config option is deprecated and no longer has any affect."
    opts.overwrite_mappings = nil
  end

  if opts.backlinks ~= nil then
    log.warn_once "The 'backlinks' config option is deprecated and no longer has any affect."
    opts.backlinks = nil
  end

  if opts.tags ~= nil then
    log.warn_once "The 'tags' config option is deprecated and no longer has any affect."
    opts.tags = nil
  end

  --------------------------
  -- Merge with defaults. --
  --------------------------

  ---@type obsidian.config.ClientOpts
  opts = tbl_override(defaults, opts)

  opts.completion = tbl_override(defaults.completion, opts.completion)
  opts.mappings = opts.mappings and opts.mappings or defaults.mappings
  opts.picker = tbl_override(defaults.picker, opts.picker)
  opts.daily_notes = tbl_override(defaults.daily_notes, opts.daily_notes)
  opts.templates = tbl_override(defaults.templates, opts.templates)
  opts.ui = tbl_override(defaults.ui, opts.ui)
  opts.attachments = tbl_override(defaults.attachments, opts.attachments)

  ---------------
  -- Validate. --
  ---------------

  if opts.sort_by ~= nil and not vim.tbl_contains(vim.tbl_values(config.SortBy), opts.sort_by) then
    error("Invalid 'sort_by' option '" .. opts.sort_by .. "' in obsidian.nvim config.")
  end

  if not util.tbl_is_array(opts.workspaces) then
    error "Invalid obsidian.nvim config, the 'config.workspaces' should be an array/list."
  end

  -- Convert dir to workspace format.
  if opts.dir ~= nil then
    table.insert(opts.workspaces, 1, { path = opts.dir })
  end

  return opts
end

---@enum obsidian.config.OpenStrategy
config.OpenStrategy = {
  current = "current",
  vsplit = "vsplit",
  hsplit = "hsplit",
}

---@enum obsidian.config.SortBy
config.SortBy = {
  path = "path",
  modified = "modified",
  accessed = "accessed",
  created = "created",
}

---@enum obsidian.config.NewNotesLocation
config.NewNotesLocation = {
  current_dir = "current_dir",
  notes_subdir = "notes_subdir",
}

---@enum obsidian.config.LinkStyle
config.LinkStyle = {
  wiki = "wiki",
  markdown = "markdown",
}

---@class obsidian.config.CompletionOpts
---
---@field nvim_cmp boolean
---@field min_chars integer
config.CompletionOpts = {}

--- Get defaults.
---
---@return obsidian.config.CompletionOpts
config.CompletionOpts.default = function()
  local has_nvim_cmp, _ = pcall(require, "cmp")
  return {
    nvim_cmp = has_nvim_cmp,
    min_chars = 2,
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

---@class obsidian.config.PickerMappingOpts
---
---@field new string|?
---@field insert_link string|?
config.PickerMappingOpts = {}

---Get defaults.
---@return obsidian.config.PickerMappingOpts
config.PickerMappingOpts.default = function()
  return {
    new = "<C-x>",
    insert_link = "<C-l>",
  }
end

---@enum obsidian.config.Picker
config.Picker = {
  telescope = "telescope.nvim",
  fzf_lua = "fzf-lua",
  mini = "mini.pick",
}

---@class obsidian.config.PickerOpts
---
---@field name obsidian.config.Picker|?
---@field mappings obsidian.config.PickerMappingOpts
config.PickerOpts = {}

--- Get the defaults.
---
---@return obsidian.config.PickerOpts
config.PickerOpts.default = function()
  return {
    name = nil,
    mappings = config.PickerMappingOpts.default(),
  }
end

---@class obsidian.config.DailyNotesOpts
---
---@field folder string|?
---@field date_format string|?
---@field alias_format string|?
---@field template string|?
config.DailyNotesOpts = {}

--- Get defaults.
---
---@return obsidian.config.DailyNotesOpts
config.DailyNotesOpts.default = function()
  return {
    folder = nil,
    date_format = nil,
    alias_format = nil,
  }
end

---@class obsidian.config.TemplateOpts
---
---@field subdir string
---@field date_format string|?
---@field time_format string|?
---@field substitutions table<string, function|string>|?
config.TemplateOpts = {}

--- Get defaults.
---
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
---
---@field enable boolean
---@field update_debounce integer
---@field checkboxes table{string, obsidian.config.UICharSpec}
---@field bullets obsidian.config.UICharSpec|?
---@field external_link_icon obsidian.config.UICharSpec
---@field reference_text obsidian.config.UIStyleSpec
---@field highlight_text obsidian.config.UIStyleSpec
---@field tags obsidian.config.UIStyleSpec
---@field hl_groups table{string, table}
config.UIOpts = {}

---@class obsidian.config.UICharSpec
---
---@field char string
---@field hl_group string

---@class obsidian.config.UIStyleSpec
---
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
    bullets = { char = "•", hl_group = "ObsidianBullet" },
    external_link_icon = { char = "", hl_group = "ObsidianExtLinkIcon" },
    reference_text = { hl_group = "ObsidianRefText" },
    highlight_text = { hl_group = "ObsidianHighlightText" },
    tags = { hl_group = "ObsidianTag" },
    hl_groups = {
      ObsidianTodo = { bold = true, fg = "#f78c6c" },
      ObsidianDone = { bold = true, fg = "#89ddff" },
      ObsidianRightArrow = { bold = true, fg = "#f78c6c" },
      ObsidianTilde = { bold = true, fg = "#ff5370" },
      ObsidianBullet = { bold = true, fg = "#89ddff" },
      ObsidianRefText = { underline = true, fg = "#c792ea" },
      ObsidianExtLinkIcon = { fg = "#c792ea" },
      ObsidianTag = { italic = true, fg = "#89ddff" },
      ObsidianHighlightText = { bg = "#75662e" },
    },
  }
end

---@class obsidian.config.AttachmentsOpts
---
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
