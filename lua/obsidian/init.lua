local log = require "obsidian.log"

local module_lookups = {
  abc = "obsidian.abc",
  async = "obsidian.async",
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
  Path = "obsidian.path",
  pickers = "obsidian.pickers",
  search = "obsidian.search",
  templates = "obsidian.templates",
  ui = "obsidian.ui",
  util = "obsidian.util",
  VERSION = "obsidian.version",
  Workspace = "obsidian.workspace",
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
  if obsidian._client == nil then
    print(
      "ERROR: it appears obsidian.nvim has not been setup.\n"
        .. "Please ensure obsidian.nvim loads upfront (e.g. by setting 'lazy=false' with your plugin manager) "
        .. "and then run this again."
    )
    return
  end

  local client = obsidian.get_client()
  client:command("ObsidianDebug", { raw_print = true })
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
  opts.workspaces = { { path = dir } }
  return obsidian.new(opts)
end

--- Setup a new Obsidian client. This should only be called once from an Nvim session.
---
---@param opts obsidian.config.ClientOpts
---
---@return obsidian.Client
obsidian.setup = function(opts)
  opts = obsidian.config.ClientOpts.normalize(opts)
  local client = obsidian.new(opts)
  log.set_level(client.opts.log_level)

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

  local group = vim.api.nvim_create_augroup("obsidian_setup", { clear = true })

  -- Complete setup and update workspace (if needed) when entering a markdown buffer.
  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    group = group,
    pattern = "*.md",
    callback = function(ev)
      -- Set the current directory of the buffer.
      local buf_dir = vim.fs.dirname(ev.match)
      if buf_dir then
        client.buf_dir = obsidian.Path.new(buf_dir)
      end

      -- Check if we're in *any* workspace.
      local workspace = obsidian.Workspace.get_workspace_for_dir(buf_dir, client.opts.workspaces)
      if not workspace then
        return
      end

      -- Switch to the workspace and complete the workspace setup.
      if not client.current_workspace.locked and workspace ~= client.current_workspace then
        log.debug("Switching to workspace '%s' @ '%s'", workspace.name, workspace.path)
        client:set_workspace(workspace)
      end

      -- Register mappings.
      for mapping_keys, mapping_config in pairs(opts.mappings) do
        vim.keymap.set("n", mapping_keys, mapping_config.action, mapping_config.opts)
      end

      -- Inject Obsidian as a cmp source.
      if opts.completion.nvim_cmp then
        local cmp = require "cmp"

        local sources = {
          { name = "obsidian" },
          { name = "obsidian_new" },
          { name = "obsidian_tags" },
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

  -- Add/update frontmatter for notes before writing.
  vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    group = group,
    pattern = "*.md",
    callback = function(ev)
      local buf_dir = vim.fs.dirname(ev.match)

      -- Check if we're in a workspace.
      local workspace = obsidian.Workspace.get_workspace_for_dir(buf_dir, client.opts.workspaces)
      if not workspace then
        return
      end

      if not client:path_is_note(ev.match, workspace) then
        return
      end

      local bufnr = ev.buf
      local note = obsidian.Note.from_buffer(bufnr)
      if not client:should_save_frontmatter(note) then
        return
      end

      local frontmatter = nil
      if client.opts.note_frontmatter_func ~= nil then
        frontmatter = client.opts.note_frontmatter_func(note)
      end

      local updated = note:save_to_buffer(bufnr, frontmatter)
      if not client._quiet and updated then
        log.info "Updated frontmatter"
      end
    end,
  })

  -- Set global client.
  obsidian._client = client

  return client
end

return obsidian
