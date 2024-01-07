local log = require "obsidian.log"

local module_lookups = {
  abc = "obsidian.abc",
  async = "obsidian.async",
  backlinks = "obsidian.backlinks",
  Client = "obsidian.client",
  collections = "obsidian.collections",
  commands = "obsidian.commands",
  completion = "obsidian.completion",
  config = "obsidian.config",
  log = "obsidian.log",
  img_paste = "obsidian.img_paste",
  itertools = "obsidian.itertools",
  mappings = "obsidian.mappings",
  Note = "obsidian.note",
  search = "obsidian.search",
  templates = "obsidian.templates",
  ui = "obsidian.ui",
  util = "obsidian.util",
  VERSION = "obsidian.version",
  workspace = "obsidian.workspace",
  yaml = "obsidian.yaml",
}

local obsidian = setmetatable({}, {
  __index = function(t, k)
    local require_path = module_lookups[k]
    if not require_path then
      return
    end

    local mod = require(require_path)
    t[k] = mod

    return mod
  end,
})

---@type obsidian.Client|?
obsidian._client = nil

---Get the current obsidian client.
---@return obsidian.Client
obsidian.get_client = function()
  if obsidian._client == nil then
    error "Obsidian client has not been set! Did you forget to call 'setup()'?"
  else
    return obsidian._client
  end
end

---Print general information about the current installation of Obsidian.nvim.
obsidian.info = function()
  local iter = obsidian.itertools.iter

  local info = obsidian.util.get_plugin_info()
  if info ~= nil then
    print("[obsidian.nvim (v" .. obsidian.VERSION .. ")] " .. info)
  else
    print(
      "ERROR: could not find path to obsidian.nvim installation.\n"
        .. "Please ensure obsidian.nvim loads upfront (e.g. by setting 'lazy=false' with your plugin manager) "
        .. "and then run this again."
    )
    return
  end

  for plugin in iter { "plenary.nvim", "nvim-cmp", "telescope.nvim", "fzf-lua", "fzf.vim", "mini.pick", "vim-markdown" } do
    local plugin_info = obsidian.util.get_plugin_info(plugin)
    if plugin_info ~= nil then
      print("[" .. plugin .. "] " .. plugin_info)
    end
  end

  for cmd in iter { "rg" } do
    local cmd_info = obsidian.util.get_external_depency_info(cmd)
    if cmd_info ~= nil then
      print(cmd_info)
    end
  end
end

---Create a new Obsidian client without additional setup.
---
---@param opts obsidian.config.ClientOpts
---@return obsidian.Client
obsidian.new = function(opts)
  return obsidian.Client.new(opts)
end

---Create a new Obsidian client in a given vault directory.
---
---@param dir string
---@return obsidian.Client
obsidian.new_from_dir = function(dir)
  local opts = obsidian.config.ClientOpts.default()
  opts.workspaces = vim.tbl_extend("force", { obsidian.workspace.new_from_dir(dir) }, opts.workspaces)
  return obsidian.new(opts)
end

---Setup a new Obsidian client.
---
---@param opts obsidian.config.ClientOpts
---@return obsidian.Client
obsidian.setup = function(opts)
  local Path = require "plenary.path"

  opts = obsidian.config.ClientOpts.normalize(opts)
  local client = obsidian.new(opts)
  log.set_level(client.opts.log_level)

  -- Ensure directories exist.
  client.dir:mkdir { parents = true, exists_ok = true }
  vim.cmd("set path+=" .. vim.fn.fnameescape(tostring(client.dir)))

  if client.opts.notes_subdir ~= nil then
    local notes_subdir = client.dir / client.opts.notes_subdir
    notes_subdir:mkdir { parents = true, exists_ok = true }
    vim.cmd("set path+=" .. vim.fn.fnameescape(tostring(notes_subdir)))
  end

  if client.opts.daily_notes.folder ~= nil then
    local daily_notes_subdir = client.dir / client.opts.daily_notes.folder
    daily_notes_subdir:mkdir { parents = true, exists_ok = true }
    vim.cmd("set path+=" .. vim.fn.fnameescape(tostring(daily_notes_subdir)))
  end

  --- @type fun(match: string): boolean
  local is_template
  local templates_dir = client:templates_dir()
  if templates_dir ~= nil then
    local templates_pattern = tostring(templates_dir)
    templates_pattern = obsidian.util.escape_magic_characters(templates_pattern)
    templates_pattern = "^" .. templates_pattern .. ".*"
    is_template = function(match)
      return string.find(match, templates_pattern) ~= nil
    end
  else
    is_template = function(_)
      return false
    end
  end

  -- Install commands.
  -- These will be available across all buffers, not just note buffers in the vault.
  obsidian.commands.install(client)

  -- Register cmp sources.
  if opts.completion.nvim_cmp then
    local cmp = require "cmp"

    cmp.register_source("obsidian", require("cmp_obsidian").new())
    cmp.register_source("obsidian_new", require("cmp_obsidian_new").new())
    cmp.register_source("obsidian_tags", require("cmp_obsidian_tags").new())
  end

  -- Setup UI add-ons.
  if client.opts.ui.enable then
    obsidian.ui.setup(client.opts.ui)
  end

  -- Register autocommands.
  local group = vim.api.nvim_create_augroup("obsidian_setup", { clear = true })

  -- Only register commands, mappings, cmp source, etc when we enter a note buffer.
  for _, workspace in ipairs(client.opts.workspaces) do
    -- NOTE: workspace.path has already been normalized
    local pattern = tostring(Path:new(workspace.path) / "**.md")

    vim.api.nvim_create_autocmd({ "BufEnter" }, {
      group = group,
      pattern = pattern,
      callback = function()
        -- Set the current directory of the buffer.
        local buf_dir = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
        if buf_dir then
          client.buf_dir = Path:new(buf_dir)
        end

        -- Register mappings.
        for mapping_keys, mapping_config in pairs(opts.mappings) do
          vim.keymap.set("n", mapping_keys, mapping_config.action, mapping_config.opts)
        end

        vim.cmd [[ setlocal suffixesadd+=.md ]]

        if opts.completion.nvim_cmp then
          -- Inject Obsidian as a cmp source when reading a buffer in the vault.
          local cmp = require "cmp"

          local sources = {
            { name = "obsidian", option = opts },
            { name = "obsidian_new", option = opts },
            { name = "obsidian_tags", option = opts },
          }
          for _, source in pairs(cmp.get_config().sources) do
            if source.name ~= "obsidian" and source.name ~= "obsidian_new" and source.name ~= "obsidian_tags" then
              table.insert(sources, source)
            end
          end
          ---@diagnostic disable-next-line: missing-fields
          cmp.setup.buffer { sources = sources }
        end
      end,
    })

    -- Add/update frontmatter on BufWritePre
    vim.api.nvim_create_autocmd({ "BufWritePre" }, {
      group = group,
      pattern = pattern,
      callback = function(ev)
        if is_template(ev.match) then
          return
        end

        local bufnr = ev.buf
        local note = obsidian.Note.from_buffer(bufnr, client.dir)
        if not client:should_save_frontmatter(note) then
          return
        end

        local frontmatter = nil
        if client.opts.note_frontmatter_func ~= nil then
          frontmatter = client.opts.note_frontmatter_func(note)
        end
        local new_lines = note:frontmatter_lines(nil, frontmatter)
        local cur_lines
        if note.frontmatter_end_line ~= nil then
          cur_lines = vim.api.nvim_buf_get_lines(0, 0, note.frontmatter_end_line, false)
        end

        vim.api.nvim_buf_set_lines(
          bufnr,
          0,
          note.frontmatter_end_line and note.frontmatter_end_line or 0,
          false,
          new_lines
        )
        if not client._quiet and not vim.deep_equal(cur_lines, new_lines) then
          log.info "Updated frontmatter"
        end
      end,
    })
  end

  -- Set global client.
  obsidian._client = client

  return client
end

return obsidian
