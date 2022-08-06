local Path = require "plenary.path"

local echo = require "obsidian.echo"

local obsidian = {}

obsidian.VERSION = "1.0.0"
obsidian.completion = require "obsidian.completion"
obsidian.note = require "obsidian.note"
obsidian.util = require "obsidian.util"

---@class obsidian.Client
---@field dir Path
local client = {}

---Create a new Obsidian client without additional setup.
---
---@param dir string|Path
---@return obsidian.Client
obsidian.new = function(dir)
  -- Setup highlight groups.
  echo.setup()

  local self = setmetatable({}, { __index = client })
  self.dir = Path:new(vim.fs.normalize(tostring(dir and dir or "./")))

  return self
end

---Setup a new Obsidian client.
---
---@param opts obsidian.config.ClientOpts
---@return obsidian.Client
obsidian.setup = function(opts)
  local config = require "obsidian.config"

  opts = config.ClientOpts.normalize(opts)
  local self = obsidian.new(opts.dir)

  -- Ensure directory exists.
  self.dir:mkdir { parents = true, exits_ok = true }

  -- Complete the lazy setup only when entering a buffer in the vault.
  local lazy_setup = function()
    -- Register commands.
    require("obsidian.command").register_all(self)

    -- Configure completion...
    if opts.completion.nvim_cmp then
      -- Check for ripgrep.
      if os.execute "rg --help" > 0 then
        echo.err "Can't find 'rg' command! Did you forget to install ripgrep?"
      end

      -- Add source.
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
  end

  -- Autocommands...
  local group = vim.api.nvim_create_augroup("obsidian_setup", { clear = true })

  -- Complete lazy setup on BufEnter
  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    group = group,
    pattern = tostring(self.dir) .. "/**.md",
    callback = lazy_setup,
  })

  -- Add missing frontmatter on BufWritePre
  vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    group = group,
    pattern = tostring(self.dir) .. "/**.md",
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      local note = obsidian.note.from_buffer(bufnr, self.dir)
      if note:should_save_frontmatter() then
        local lines = note:frontmatter_lines()
        vim.api.nvim_buf_set_lines(bufnr, 0, 0, true, lines)
        echo.info "Updated frontmatter"
      end
    end,
  })

  return self
end

---Find the path to the actual Obsidian vault (it may be in a parent of 'self.dir').
---
---@return string|?
client.vault = function(self)
  local vault_indicator_folder = ".obsidian"
  local dirs = self.dir:parents()
  table.insert(dirs, self.dir:absolute())
  for _, parent in pairs(self.dir:parents()) do
    ---@type Path
    ---@diagnostic disable-next-line: assign-type-mismatch
    local maybe_vault = Path:new(parent) / vault_indicator_folder
    if maybe_vault:is_dir() then
      return parent
    end
  end
  return nil
end

---Search for notes. Returns an iterator over matching notes.
---
---@param search string
---@return function
client.search = function(self, search)
  local search_results = obsidian.util.search(self.dir, search)

  ---@return obsidian.Note|?
  return function()
    local path = search_results()
    if path == nil then
      return nil
    else
      return obsidian.note.from_file(path, self.dir)
    end
  end
end

return obsidian
