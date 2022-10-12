local Path = require "plenary.path"

local echo = require "obsidian.echo"
local config = require "obsidian.config"

local obsidian = {}

obsidian.VERSION = "1.5.0"
obsidian.completion = require "obsidian.completion"
obsidian.note = require "obsidian.note"
obsidian.util = require "obsidian.util"

---@class obsidian.Client
---@field dir Path
---@field opts obsidian.config.ClientOpts
---@field backlinks_namespace integer
local client = {}

---Create a new Obsidian client without additional setup.
---
---@param opts obsidian.config.ClientOpts
---@return obsidian.Client
obsidian.new = function(opts)
  -- Setup highlight groups.
  echo.setup()

  local self = setmetatable({}, { __index = client })
  self.dir = Path:new(vim.fs.normalize(tostring(opts.dir and opts.dir or "./")))
  self.opts = opts
  self.backlinks_namespace = vim.api.nvim_create_namespace "ObsidianBacklinks"

  return self
end

---Create a new Obsidian client in a given vault directory.
---
---@param dir string
---@return obsidian.Client
obsidian.new_from_dir = function(dir)
  local opts = config.ClientOpts.default()
  opts.dir = vim.fs.normalize(dir)
  return obsidian.new(opts)
end

---Setup a new Obsidian client.
---
---@param opts obsidian.config.ClientOpts
---@return obsidian.Client
obsidian.setup = function(opts)
  opts = config.ClientOpts.normalize(opts)
  local self = obsidian.new(opts)

  -- Ensure directories exist.
  self.dir:mkdir { parents = true, exists_ok = true }

  if self.opts.notes_subdir ~= nil then
    (self.dir / self.opts.notes_subdir):mkdir { parents = true, exists_ok = true }
  end

  if self.opts.daily_notes.folder ~= nil then
    (self.dir / self.opts.daily_notes.folder):mkdir { parents = true, exists_ok = true }
  end

  -- Register commands.
  require("obsidian.command").register_all(self)

  -- Complete the lazy setup only when entering a buffer in the vault.
  local lazy_setup = function()
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
    pattern = tostring(self.dir / "**.md"),
    callback = lazy_setup,
  })

  -- Add missing frontmatter on BufWritePre
  vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    group = group,
    pattern = tostring(self.dir / "**.md"),
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
  table.insert(dirs, 0, self.dir:absolute())
  for _, dir in pairs(dirs) do
    ---@type Path
    ---@diagnostic disable-next-line: assign-type-mismatch
    local maybe_vault = Path:new(dir) / vault_indicator_folder
    if maybe_vault:is_dir() then
      return dir
    end
  end
  return nil
end

---Search for notes. Returns an iterator over matching notes.
---
---@param search string
---@return function
client.search = function(self, search)
  local search_results = obsidian.util.search(self.dir, search, "-m 1")

  ---@return obsidian.Note|?
  return function()
    local match = search_results()
    if match == nil then
      return nil
    else
      return obsidian.note.from_file(match.path.text, self.dir)
    end
  end
end

---Create a new Zettel ID
---
---@param title string|?
---@return string
client.new_note_id = function(self, title)
  if self.opts.note_id_func ~= nil then
    local new_id = self.opts.note_id_func(title)
    -- Remote '.md' suffix if it's there (we add that later).
    new_id = new_id:gsub("%.md$", "", 1)
    return new_id
  else
    return obsidian.util.zettel_id()
  end
end

---Create and save a new note.
---
---@param title string|?
---@param id string|?
---@return obsidian.Note
client.new_note = function(self, title, id)
  -- Generate new ID.
  local new_id = id and id or self:new_note_id(title)

  -- Get path.
  ---@type Path
  local path = Path:new(self.dir)
  if self.opts.notes_subdir ~= nil then
    ---@type Path
    ---@diagnostic disable-next-line: assign-type-mismatch
    path = path / self.opts.notes_subdir
  end
  ---@type Path
  ---@diagnostic disable-next-line: assign-type-mismatch
  path = path / (new_id .. ".md")

  -- Add title as an alias.
  local aliases
  if title ~= nil and title:len() > 0 then
    aliases = { title }
  else
    aliases = {}
  end

  -- Create Note object and save.
  local note = obsidian.note.new(new_id, aliases, {}, path)
  note:save()
  echo.info("Created note " .. tostring(note.id) .. " at " .. tostring(note.path))

  return note
end

---Create a new daily note for today.
---
---@return obsidian.Note
client.today = function(self)
  ---@type string
  ---@diagnostic disable-next-line: assign-type-mismatch
  local id = os.date "%Y-%m-%d"
  local alias = os.date "%B %-d, %Y"
  ---@type Path
  local path = Path:new(self.dir)

  if self.opts.daily_notes.folder ~= nil then
    ---@type Path
    ---@diagnostic disable-next-line: assign-type-mismatch
    path = path / self.opts.daily_notes.folder
  elseif self.opts.notes_subdir ~= nil then
    ---@type Path
    ---@diagnostic disable-next-line: assign-type-mismatch
    path = path / self.opts.notes_subdir
  end
  ---@type Path
  ---@diagnostic disable-next-line: assign-type-mismatch
  path = path / (id .. ".md")

  -- Create Note object and save if it doesn't already exist.
  local note = obsidian.note.new(id, { alias }, { "daily-notes" }, path)
  if not note:exists() then
    note:save()
    echo.info("Created note " .. tostring(note.id) .. " at " .. tostring(note.path))
  end

  return note
end

return obsidian
