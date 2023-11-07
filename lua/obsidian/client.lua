local Path = require "plenary.path"
local workspace = require "obsidian.workspace"
local util = require "obsidian.util"
local echo = require "obsidian.echo"
local Note = require "obsidian.note"

---@class obsidian.Client
---@field current_workspace obsidian.Workspace
---@field dir Path
---@field templates_dir Path|?
---@field opts obsidian.config.ClientOpts
---@field backlinks_namespace integer
local Client = {}

---Create a new Obsidian client without additional setup.
---
---@param opts obsidian.config.ClientOpts
---@return obsidian.Client
Client.new = function(opts)
  local self = setmetatable({}, { __index = Client })

  self.current_workspace = workspace.get_from_opts(opts)
  -- NOTE: workspace.path has already been normalized
  self.dir = Path:new(self.current_workspace.path)
  self.opts = opts
  self.backlinks_namespace = vim.api.nvim_create_namespace "ObsidianBacklinks"
  if self.opts.yaml_parser ~= nil then
    local yaml = require "obsidian.yaml"
    yaml.set_parser(self.opts.yaml_parser)
  end

  return self
end

---Find the path to the actual Obsidian vault (it may be in a parent of 'self.dir').
---
---@return string|?
Client.vault = function(self)
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

---@param search string
---@param search_opts string[]|?
---@return function
Client._search_iter_async = function(self, search, search_opts)
  local channel = require("plenary.async.control").channel
  local search_async = require("obsidian.search").search_async
  local find_async = require("obsidian.search").find_async
  local tx, rx = channel.mpsc()
  local found = {}

  local function on_exit(_)
    tx.send(nil)
  end

  local function on_search_match(content_match)
    local path = vim.fs.normalize(content_match.path.text)
    if not found[path] then
      found[path] = true
      tx.send(path)
    end
  end

  local function on_find_match(path_match)
    local path = vim.fs.normalize(path_match)
    if not found[path] then
      found[path] = true
      tx.send(path)
    end
  end

  local cmds_done = 0 -- out of the two, one for 'search' and one for 'find'
  search_opts = search_opts and search_opts or {}
  search_async(self.dir, search, vim.tbl_flatten { search_opts, "-m=1" }, on_search_match, on_exit)
  find_async(self.dir, search, self.opts.sort_by, self.opts.sort_reversed, on_find_match, on_exit)

  return function()
    while true do
      if cmds_done >= 2 then
        return nil
      end

      local value = rx.recv()
      if value == nil then
        cmds_done = cmds_done + 1
      else
        return value
      end
    end
  end
end

---Search for notes.
---
---@param search string
---@param search_opts string[]|?
---@return obsidian.Note[]
Client.search = function(self, search, search_opts)
  local done = false
  local results = {}

  local function collect_results(results_)
    results = results_
    done = true
  end

  self:search_async(search, search_opts, collect_results)

  while not done do
    vim.wait(100)
  end
  return results
end

---An async version of `search()` that runs the callback with an array of all matching notes.
---
---@param search string
---@param search_opts string[]|?
---@param callback function
Client.search_async = function(self, search, search_opts, callback)
  local async = require "plenary.async"
  local next_path = self:_search_iter_async(search, search_opts)
  local executor = require("obsidian.async").AsyncExecutor.new()
  local dir = tostring(self.dir)

  local function task_fn(path)
    return Note.from_file_async(path, dir)
  end

  async.run(function()
    executor:map(task_fn, next_path, callback)
  end, function(_) end)
end

---Create a new Zettel ID
---
---@param title string|?
---@return string
Client.new_note_id = function(self, title)
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
    return util.zettel_id()
  end
end

---Parse the title, ID, and path for a new note.
---
---@param title string|?
---@param id string|?
---@param dir string|Path|?
---
---@return string|?,string,Path
Client.parse_title_id_path = function(self, title, id, dir)
  ---@type Path
  local base_dir = dir == nil and Path:new(self.dir) or Path:new(dir)
  local title_is_path = false

  -- Clean up title and guess the right base_dir.
  if title ~= nil then
    -- Trim whitespace.
    title = title:match "^%s*(.-)%s*$"

    if title:match "%.md" then
      -- Remove suffix.
      title = title:sub(1, title:len() - 3)
      title_is_path = true
    end

    -- Pull out any parent dirs from title.
    local parts = vim.split(title, Path.path.sep)
    if #parts > 1 then
      -- 'title' will just be the final part of the path.
      title = parts[#parts]
      -- Add the other parts to the base_dir.
      base_dir = base_dir / table.concat(parts, Path.path.sep, 1, #parts - 1)
    elseif dir == nil and self.opts.notes_subdir ~= nil then
      base_dir = base_dir / self.opts.notes_subdir
    end
  elseif dir == nil and self.opts.notes_subdir ~= nil then
    base_dir = base_dir / self.opts.notes_subdir
  end

  if title == "" then
    title = nil
  end

  -- Generate new ID if needed.
  local new_id = id and id or (title_is_path and title or self:new_note_id(title))

  -- Get path.
  ---@type Path
  ---@diagnostic disable-next-line: assign-type-mismatch
  local path = base_dir / (new_id .. ".md")

  return title, new_id, path
end

---Create and save a new note.
---
---@param title string|?
---@param id string|?
---@param dir string|Path|?
---@param aliases string[]|?
---
---@return obsidian.Note
Client.new_note = function(self, title, id, dir, aliases)
  local new_title, new_id, path = self:parse_title_id_path(title, id, dir)

  if new_id == tostring(os.date "%Y-%m-%d") then
    return self:today()
  end

  -- Add title as an alias.
  ---@type string[]
  ---@diagnostic disable-next-line: assign-type-mismatch
  aliases = aliases == nil and {} or aliases
  if new_title ~= nil and new_title:len() > 0 and not util.contains(aliases, new_title) then
    aliases[#aliases + 1] = new_title
  end

  -- Create Note object and save.
  local note = Note.new(new_id, aliases, {}, path)
  local frontmatter = nil
  if self.opts.note_frontmatter_func ~= nil then
    frontmatter = self.opts.note_frontmatter_func(note)
  end
  note:save(nil, not self.opts.disable_frontmatter, frontmatter)
  echo.info("Created note " .. tostring(note.id) .. " at " .. tostring(note.path), self.opts.log_level)

  return note
end

---Get the path to a daily note.
---
---@param id string
---@return Path
Client.daily_note_path = function(self, id)
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

---Open (or create) the daily note.
---
---@param self obsidian.Client
---@param datetime integer
---@return obsidian.Note
Client._daily = function(self, datetime)
  local id
  if self.opts.daily_notes.date_format ~= nil then
    id = tostring(os.date(self.opts.daily_notes.date_format, datetime))
  else
    id = tostring(os.date("%Y-%m-%d", datetime))
  end

  local path = self:daily_note_path(id)

  local alias
  if self.opts.daily_notes.alias_format ~= nil then
    alias = tostring(os.date(self.opts.daily_notes.alias_format, datetime))
  else
    alias = tostring(os.date("%B %-d, %Y", datetime))
  end

  -- Create Note object and save if it doesn't already exist.
  local note = Note.new(id, { alias }, { "daily-notes" }, path)
  if not note:exists() then
    if self.opts.daily_notes.template then
      util.clone_template(self.opts.daily_notes.template, tostring(path), self, note:display_name())
    end
    local frontmatter = nil
    if self.opts.note_frontmatter_func ~= nil then
      frontmatter = self.opts.note_frontmatter_func(note)
    end
    note:save(nil, not self.opts.disable_frontmatter, frontmatter)
    echo.info("Created note " .. tostring(note.id) .. " at " .. tostring(note.path), self.opts.log_level)
  end

  return note
end

---Open (or create) the daily note for today.
---
---@return obsidian.Note
Client.today = function(self)
  return self:_daily(os.time())
end

---Open (or create) the daily note from the last weekday.
---
---@return obsidian.Note
Client.yesterday = function(self)
  return self:_daily(util.working_day_before(os.time()))
end

---Resolve the query to a single note.
---
---@param query string
---@return obsidian.Note|?
Client.resolve_note = function(self, query)
  -- Autocompletion for command args will have this format.
  local note_path, count = string.gsub(query, "^.*  ", "")
  if count > 0 then
    ---@type Path
    ---@diagnostic disable-next-line: assign-type-mismatch
    local full_path = self.dir / note_path
    return Note.from_file(full_path, self.dir)
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
      local ok, note = pcall(Note.from_file, path)
      if ok then
        return note
      end
    end
  end

  local query_lwr = string.lower(query)
  local maybe_matches = {}
  for note in self:search(query, { "--ignore-case" }) do
    if query == note.id or query == note:display_name() or util.contains(note.aliases, query) then
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

Client._run_with_finder_backend = function(self, command_name, implementations)
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
  local success, err = pcall(util.run_first_supported, command_name, finders_order, implementations)
  if not success then
    if type(err) == "string" then
      echo.err(err, Client.opts.log_level)
    else
      error(err)
    end
  end
end

return Client
