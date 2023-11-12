local module_lookups = {
  async = "obsidian.async",
  backlinks = "obsidian.backlinks",
  Client = "obsidian.client",
  command = "obsidian.command",
  completion = "obsidian.completion",
  config = "obsidian.config",
  echo = "obsidian.echo",
  mapping = "obsidian.mapping",
  Note = "obsidian.note",
  search = "obsidian.search",
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

  for _, plugin in ipairs { "plenary.nvim", "nvim-cmp", "telescope.nvim", "fzf-lua", "fzf.vim", "vim-markdown" } do
    local plugin_info = obsidian.util.get_plugin_info(plugin)
    if plugin_info ~= nil then
      print("[" .. plugin .. "] " .. plugin_info)
    end
  end

  for _, cmd in ipairs { "rg" } do
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

  client.templates_dir = nil
  if client.opts.templates ~= nil and client.opts.templates.subdir ~= nil then
    client.templates_dir = Path:new(client.dir) / client.opts.templates.subdir
    if not client.templates_dir:is_dir() then
      obsidian.echo.err(
        string.format("%s is not a valid directory for templates", client.templates_dir),
        client.opts.log_level
      )
      client.templates_dir = nil
    end
  end

  -- Install commands.
  obsidian.command.install(client)

  -- Register mappings.
  for mapping_keys, mapping_config in pairs(opts.mappings) do
    vim.keymap.set("n", mapping_keys, mapping_config.action, mapping_config.opts)
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

  -- Register autocommands.
  local group = vim.api.nvim_create_augroup("obsidian_setup", { clear = true })

  if opts.completion.nvim_cmp then
    -- Inject Obsidian as a cmp source when reading a buffer in the vault.
    local cmp_setup = function()
      local cmp = require "cmp"
      local sources = {
        { name = "obsidian", option = opts },
        { name = "obsidian_new", option = opts },
      }
      for _, source in pairs(cmp.get_config().sources) do
        if source.name ~= "obsidian" and source.name ~= "obsidian_new" then
          table.insert(sources, source)
        end
      end
      cmp.setup.buffer { sources = sources }
    end

    vim.api.nvim_create_autocmd({ "BufRead" }, {
      group = group,
      pattern = tostring(client.dir / "**.md"),
      callback = cmp_setup,
    })
  end

  -- Add missing frontmatter on BufWritePre
  vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    group = group,
    pattern = tostring(client.dir / "**.md"),
    callback = function(args)
      if is_template(args.match) then
        return
      end

      local bufnr = vim.api.nvim_get_current_buf()
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
      obsidian.echo.info("Updated frontmatter", client.opts.log_level)
    end,
  })

  return client
end

return obsidian
