local Path = require "plenary.path"

local echo = require "obsidian.echo"
local config = require "obsidian.config"

local obsidian = {}

obsidian.VERSION = "1.10.0"
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
  vim.cmd("set path+=" .. vim.fn.fnameescape(tostring(self.dir)))

  if self.opts.notes_subdir ~= nil then
    local notes_subdir = self.dir / self.opts.notes_subdir
    notes_subdir:mkdir { parents = true, exists_ok = true }
    vim.cmd("set path+=" .. vim.fn.fnameescape(tostring(notes_subdir)))
  end

  if self.opts.daily_notes.folder ~= nil then
    local daily_notes_subdir = self.dir / self.opts.daily_notes.folder
    daily_notes_subdir:mkdir { parents = true, exists_ok = true }
    vim.cmd("set path+=" .. vim.fn.fnameescape(tostring(daily_notes_subdir)))
  end

  -- Register commands.
  require("obsidian.command").register_all(self)

  -- Complete the lazy setup only when entering a buffer in the vault.
  local lazy_setup = function()
    -- Configure completion...
    if opts.completion.nvim_cmp then
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
      if note:should_save_frontmatter() and self.opts.disable_frontmatter ~= true then
        local frontmatter = nil
        if self.opts.note_frontmatter_func ~= nil then
          frontmatter = self.opts.note_frontmatter_func(note)
        end
        local lines = note:frontmatter_lines(nil, frontmatter)
        vim.api.nvim_buf_set_lines(bufnr, 0, note.frontmatter_end_line and note.frontmatter_end_line or 0, false, lines)
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
---@param search_opts string|?
---@return function
client.search = function(self, search, search_opts)
  search_opts = search_opts and (search_opts .. " ") or ""
  local search_results = obsidian.util.search(self.dir, search, search_opts .. "-m 1")
  local find_results = obsidian.util.find(self.dir, search)

  local found = {}
  local note = nil

  ---@return obsidian.Note|?
  return function()
    local content_match = search_results()
    if content_match ~= nil then
      note = obsidian.note.from_file(content_match.path.text, self.dir)
      found[#found + 1] = note.id
      return note
    end

    local path_match = find_results()
    note = path_match ~= nil and obsidian.note.from_file(path_match, self.dir) or nil
    -- keep looking until we get a new match that we haven't seen yet.
    while path_match ~= nil and note ~= nil and obsidian.util.contains(found, note.id) do
      path_match = find_results()
      note = path_match ~= nil and obsidian.note.from_file(path_match, self.dir) or nil
    end

    if note ~= nil then
      return note
    end

    return nil
  end
end

---Create a new Zettel ID
---
---@param title string|?
---@return string
client.new_note_id = function(self, title)
  local today_id = tostring(os.date "%Y-%m-%d")
  if
    title ~= nil
    and string.len(title) >= 5
    and string.find(today_id, title, 1, true) == 1
    and not self:daily_note_path(today_id):is_file()
  then
    return today_id
  elseif self.opts.note_id_func ~= nil then
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
---@param dir string|Path|?
---@return obsidian.Note
client.new_note = function(self, title, id, dir)
  -- Generate new ID if needed.
  local new_id = id and id or self:new_note_id(title)
  if new_id == tostring(os.date "%Y-%m-%d") then
    return self:today()
  end

  -- Get path.
  ---@type Path
  local path = dir == nil and Path:new(self.dir) or Path:new(dir)
  if dir == nil and self.opts.notes_subdir ~= nil then
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
  note:save(nil, not self.opts.disable_frontmatter)
  echo.info("Created note " .. tostring(note.id) .. " at " .. tostring(note.path))

  return note
end

---Get the path to a daily note.
---
---@param id string
---@return Path
client.daily_note_path = function(self, id)
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
  return path
end

---Create a new daily note for today.
---
---@return obsidian.Note
client.today = function(self)
  ---@type string
  ---@diagnostic disable-next-line: assign-type-mismatch
  local formatted_date
  if self.opts.daily_notes.date_format ~= nil then
    formatted_date = os.date(self.opts.daily_notes.date_format)
  else
    formatted_date = os.date("%Y-%m-%d")
  end
  local id = formatted_date
  local alias = os.date "%B %-d, %Y"
  local path = self:daily_note_path(id)

  -- Create Note object and save if it doesn't already exist.
  local note = obsidian.note.new(id, { alias }, { "daily-notes" }, path)
  if not note:exists() then
    note:save(nil, not self.opts.disable_frontmatter)
    echo.info("Created note " .. tostring(note.id) .. " at " .. tostring(note.path))
  end

  return note
end

---Open (or create) the daily note from the last weekday.
---
---@return obsidian.Note
client.yesterday = function(self)
  ---@type string
  ---@diagnostic disable-next-line: assign-type-mismatch
  local today = os.time()
  local yesterday = obsidian.util.working_day_before(today)
  local id
  if self.opts.daily_notes.date_format ~= nil then
    id = tostring(os.date(self.opts.daily_notes.date_format, yesterday))
  else
    id = tostring(os.date("%Y-%m-%d", yesterday))
  end
  local alias = tostring(os.date("%B %-d, %Y", yesterday))
  local path = self:daily_note_path(id)

  -- Create Note object and save if it doesn't already exist.
  local note = obsidian.note.new(id, { alias }, { "daily-notes" }, path)
  if not note:exists() then
    note:save(nil, not self.opts.disable_frontmatter)
    echo.info("Created note " .. tostring(note.id) .. " at " .. tostring(note.path))
  end

  return note
end

---Resolve the query to a single note.
---
---@param query string
---@return obsidian.Note|?
client.resolve_note = function(self, query)
  -- Autocompletion for command args will have this format.
  local note_path, count = string.gsub(query, "^.*  ", "")
  if count > 0 then
    ---@type Path
    ---@diagnostic disable-next-line: assign-type-mismatch
    local full_path = self.dir / note_path
    return obsidian.note.from_file(full_path, self.dir)
  end

  -- Query might be a path.
  local paths_to_check = { Path:new(query), self.dir / query }
  if self.opts.notes_subdir ~= nil then
    table.insert(paths_to_check, self.dir / self.opts.notes_subdir / query)
  end
  if self.opts.daily_notes.folder ~= nil then
    table.insert(paths_to_check, self.dir / self.opts.daily_notes.folder / query)
  end
  for _, path in pairs(paths_to_check) do
    if path:is_file() then
      local ok, note = pcall(obsidian.note.from_file, path)
      if ok then
        return note
      end
    end
  end

  local query_lwr = string.lower(query)
  local maybe_matches = {}
  for note in self:search(query, "--ignore-case") do
    if query == note.id or query == note:display_name() or obsidian.util.contains(note.aliases, query) then
      -- Exact match! We're done!
      return note
    end

    for _, alias in pairs(note.aliases) do
      if query_lwr == string.lower(alias) then
        -- Lower case match, save this one for later.
        table.insert(maybe_matches, note)
        break
      end
    end
  end

  if #maybe_matches > 0 then
    return maybe_matches[1]
  end

  return nil
end

client._run_with_finder_backend = function(self, command_name, implementations)
  local finders_order = { "telescope.nvim", "fzf-lua", "fzf.vim" }
  if self.opts.finder then
    for idx, finder in ipairs(finders_order) do
      if finder == self.opts.finder then
        table.remove(finders_order, idx)
        break
      end
    end
    table.insert(finders_order, 1, self.opts.finder)
  end
  local success, err = pcall(obsidian.util.run_first_supported, command_name, finders_order, implementations)
  if not success then
    if type(err) == "string" then
      echo.err(err)
    else
      error(err)
    end
  end
end

return obsidian
