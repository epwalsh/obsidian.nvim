local module_lookups = {
  async = "obsidian.async",
  backlinks = "obsidian.backlinks",
  Client = "obsidian.client",
  collections = "obsidian.collections",
  command = "obsidian.command",
  completion = "obsidian.completion",
  config = "obsidian.config",
  log = "obsidian.log",
  img_paste = "obsidian.img_paste",
  mapping = "obsidian.mapping",
  Note = "obsidian.note",
  search = "obsidian.search",
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

---Print general information about the current installation of Obsidian.nvim.
obsidian.info = function()
  local iter = obsidian.util.iter

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

  for plugin in iter { "plenary.nvim", "nvim-cmp", "telescope.nvim", "fzf-lua", "fzf.vim", "vim-markdown" } do
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
  obsidian.log.set_level(client.opts.log_level)

  -- Ensure directories exist.
  client.dir:mkdir { parents = true, exists_ok = true }
  vim.cmd("set path+=" .. vim.fn.fnameescape(tostring(client.dir)))
  if client:vault_root() ~= client.dir then
    vim.cmd("set path+=" .. vim.fn.fnameescape(tostring(client:vault_root())))
  end

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

  client.templates_dir = nil
  if client.opts.templates ~= nil and client.opts.templates.subdir ~= nil then
    client.templates_dir = Path:new(client.dir) / client.opts.templates.subdir
    if not client.templates_dir:is_dir() then
      obsidian.log.err("%s is not a valid directory for templates", client.templates_dir)
      client.templates_dir = nil
    end
  end

  --- @type fun(match: string): boolean
  local is_template
  if client.templates_dir ~= nil then
    local templates_pattern = tostring(client.templates_dir)
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
  obsidian.command.install(client)

  -- Register cmp sources.
  if opts.completion.nvim_cmp then
    local cmp = require "cmp"

    cmp.register_source("obsidian", require("cmp_obsidian").new())
    cmp.register_source("obsidian_new", require("cmp_obsidian_new").new())
    cmp.register_source("obsidian_tags", require("cmp_obsidian_tags").new())
  end

  -- Register autocommands.
  local group = vim.api.nvim_create_augroup("obsidian_setup", { clear = true })

  -- Only register commands, mappings, cmp source, etc when we enter a note buffer.
  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    group = group,
    pattern = tostring(client.dir / "**.md"),
    callback = function()
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
        cmp.setup.buffer { sources = sources }
      end
    end,
  })

  if client.opts.ui.enable then
    -- UI updates.
    vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI", "TextChangedP" }, {
      group = group,
      pattern = "*.md",
      callback = obsidian.ui.get_autocmd_callback(client.opts.ui),
    })
  end

  -- Add missing frontmatter on BufWritePre
  vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    group = group,
    pattern = tostring(client.dir / "**.md"),
    callback = function(ev)
      if is_template(ev.match) then
        return
      end

      local bufnr = ev.buf
      local note = obsidian.Note.from_buffer(bufnr, client.dir)
      if not note:should_save_frontmatter() or client.opts.disable_frontmatter == true then
        return
      end

      local frontmatter = nil
      if client.opts.note_frontmatter_func ~= nil then
        frontmatter = client.opts.note_frontmatter_func(note)
      end
      local lines = note:frontmatter_lines(nil, frontmatter)
      vim.api.nvim_buf_set_lines(bufnr, 0, note.frontmatter_end_line and note.frontmatter_end_line or 0, false, lines)
      if not client._quiet then
        obsidian.log.info "Updated frontmatter"
      end
    end,
  })

  obsidian.get_client = function()
    return client
  end

  return client
end

return obsidian
