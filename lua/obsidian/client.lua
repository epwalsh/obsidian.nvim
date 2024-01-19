--- *obsidian-api*
---
--- The Obsidian.nvim Lua API.
---
--- ==============================================================================
---
--- Table of contents
---
---@toc

local Path = require "plenary.path"
local abc = require "obsidian.abc"
local async = require "plenary.async"
local channel = require("plenary.async.control").channel
local config = require "obsidian.config"
local Note = require "obsidian.note"
local Workspace = require "obsidian.workspace"
local log = require "obsidian.log"
local util = require "obsidian.util"
local search = require "obsidian.search"
local AsyncExecutor = require("obsidian.async").AsyncExecutor
local block_on = require("obsidian.async").block_on
local iter = require("obsidian.itertools").iter

---@class obsidian.SearchOpts : obsidian.ABC
---
---@field sort boolean|?
---@field include_templates boolean|?
---@field ignore_case boolean|?
local SearchOpts = abc.new_class {
  __tostring = function(self)
    return string.format("SearchOpts(%s)", vim.inspect(self:as_tbl()))
  end,
}

---@param opts obsidian.SearchOpts|table<string, any>
---
---@return obsidian.SearchOpts
SearchOpts.from_tbl = function(opts)
  setmetatable(opts, SearchOpts.mt)
  return opts
end

---@return obsidian.SearchOpts
SearchOpts.default = function()
  return SearchOpts.from_tbl {
    sort = false,
    include_templates = false,
    ignore_case = false,
  }
end

--- The Obsidian client is the main API for programmatically interacting with obsidian.nvim's features
--- in Lua. To get the client instance, run:
---
--- `local client = require("obsidian").get_client()`
---
---@toc_entry obsidian.Client
---
---@class obsidian.Client : obsidian.ABC
---
---@field current_workspace obsidian.Workspace The current workspace.
---@field dir Path The root of the vault for the current workspace.
---@field opts obsidian.config.ClientOpts The client config.
---@field buf_dir Path|? The parent directory of the current buffer.
---@field _default_opts obsidian.config.ClientOpts
---@field _quiet boolean
local Client = abc.new_class {
  __tostring = function(self)
    return string.format("obsidian.Client('%s')", self.dir)
  end,
}

--- Create a new Obsidian client without additional setup.
--- This is mostly used for testing. In practice you usually want to obtain the existing
--- client through:
---
--- `require("obsidian").get_client()`
---
---@param opts obsidian.config.ClientOpts
---
---@return obsidian.Client
Client.new = function(opts)
  local self = Client.init()

  self._default_opts = opts
  self._quiet = false

  local workspace = Workspace.get_from_opts(opts)
  self:set_workspace(workspace)

  if self.opts.yaml_parser ~= nil then
    local yaml = require "obsidian.yaml"
    yaml.set_parser(self.opts.yaml_parser)
  end

  return self
end

---@param workspace obsidian.Workspace
Client.set_workspace = function(self, workspace)
  self.current_workspace = workspace
  self.dir = self:vault_root(workspace)
  self.opts = config.ClientOpts.normalize(self._default_opts, workspace.overrides)
end

--- Switch to a different workspace.
---
---@param workspace obsidian.Workspace|string The workspace object or the name of an existing workspace.
Client.switch_workspace = function(self, workspace)
  if type(workspace) == "string" then
    if workspace == self.current_workspace.name then
      log.info("Already in workspace '%s' @ '%s'", workspace, self.current_workspace.path)
      return
    end

    for _, ws in ipairs(self.opts.workspaces) do
      if ws.name == workspace then
        return self:switch_workspace(ws)
      end
    end

    error(string.format("Workspace '%s' not found", workspace))
  else
    if workspace.path == self.current_workspace.path then
      log.info("Already in workspace '%s' @ '%s'", workspace.name, workspace.path)
      return
    end

    log.info("Switching to workspace '%s' @ '%s'", workspace.name, workspace.path)
    self:set_workspace(workspace)
  end
end

--- Get the absolute path to the root of the Obsidian vault for the given workspace or the
--- current workspace.
---
---@param workspace obsidian.Workspace|?
---
---@return Path
Client.vault_root = function(self, workspace)
  workspace = workspace and workspace or self.current_workspace

  local vault_indicator_folder = ".obsidian"
  local dirs = Path:new(workspace.path):parents()
  table.insert(dirs, 1, workspace.path)

  for _, dirpath in ipairs(dirs) do
    local dir = Path:new(dirpath)
    local maybe_vault = dir / vault_indicator_folder
    if maybe_vault:is_dir() then
      return dir
    end
  end

  return Path:new(workspace.path)
end

--- Get the name of the current vault.
---
---@return string
Client.vault_name = function(self)
  return assert(vim.fs.basename(tostring(self:vault_root())))
end

--- Make a path relative to the vault root, if possible.
---
---@param path string|Path
---
---@return string|?
Client.vault_relative_path = function(self, path)
  local normalized_path = vim.fs.normalize(tostring(path))
  local relative_path = Path:new(normalized_path):make_relative(tostring(self:vault_root()))
  if relative_path == normalized_path then
    -- Either `normalized_path` was already relative or `:make_relative()` failed.
    -- When `:make_relative()` fails it returns the absolute path, which can happen when the
    -- vault path is configured to look behind a link but `path` is not behind the link.
    -- In this case we look for the first occurrence of the vault name in
    -- `path` and remove everything up to and including it.
    local _, j = string.find(relative_path, self:vault_name())
    if j ~= nil then
      return string.sub(relative_path, j + 2)
    else
      return relative_path
    end
  else
    return relative_path
  end
end

--- Get the templates folder.
---
---@return Path|?
Client.templates_dir = function(self)
  if self.opts.templates ~= nil and self.opts.templates.subdir ~= nil then
    local templates_dir = self.dir / self.opts.templates.subdir
    if not templates_dir:is_dir() then
      log.err("'%s' is not a valid directory for templates", templates_dir)
      return nil
    else
      return templates_dir
    end
  else
    return nil
  end
end

--- Determines whether a note's frontmatter is managed by obsidian.nvim.
---
---@param note obsidian.Note
---
---@return boolean
Client.should_save_frontmatter = function(self, note)
  if not note:should_save_frontmatter() then
    return false
  end
  if self.opts.disable_frontmatter == nil then
    return true
  end
  if type(self.opts.disable_frontmatter) == "boolean" then
    return not self.opts.disable_frontmatter
  end
  if type(self.opts.disable_frontmatter) == "function" then
    return not self.opts.disable_frontmatter(self:vault_relative_path(note.path))
  end
  return true
end

--- Run an obsidian command directly.
---
---@usage `client:command("ObsidianNew", { args = "Foo" })`
---
---@param cmd_name string The name of the command.
---@param cmd_data table|? The payload for the command.
Client.command = function(self, cmd_name, cmd_data)
  local commands = require "obsidian.commands"

  commands[cmd_name](self, cmd_data)
end

--- Get the default search options.
---
---@return obsidian.SearchOpts
Client.search_defaults = function(self)
  local opts = SearchOpts.default()
  if opts.sort and self.opts.sort_by == nil then
    opts.sort = false
  end
  return opts
end

---@param opts obsidian.SearchOpts|boolean|?
---
---@return obsidian.SearchOpts
---
---@private
Client._search_opts_from_arg = function(self, opts)
  if opts == nil then
    opts = self:search_defaults()
  elseif type(opts) == "table" then
    opts = SearchOpts.from_tbl(opts)
  elseif type(opts) == "boolean" then
    local sort = opts
    opts = SearchOpts.default()
    opts.sort = sort
  else
    error("unexpected type for SearchOpts: '" .. type(opts) .. "'")
  end
  return opts
end

---@param opts obsidian.SearchOpts|boolean|?
---@param additional_opts obsidian.search.SearchOpts|?
---
---@return obsidian.search.SearchOpts
---
---@private
Client._prepare_search_opts = function(self, opts, additional_opts)
  opts = self:_search_opts_from_arg(opts)

  local search_opts = search.SearchOpts.default()

  if opts.sort then
    search_opts.sort_by = self.opts.sort_by
    search_opts.sort_reversed = self.opts.sort_reversed
  end

  if not opts.include_templates and self.opts.templates ~= nil and self.opts.templates.subdir ~= nil then
    search_opts:add_exclude(self.opts.templates.subdir)
  end

  if opts.ignore_case then
    search_opts.ignore_case = true
  end

  if additional_opts ~= nil then
    search_opts = search_opts:merge(additional_opts)
  end

  return search_opts
end

---@param term string
---@param search_opts obsidian.SearchOpts|boolean|?
---@param find_opts obsidian.SearchOpts|boolean|?
---
---@return function
---
---@private
Client._search_iter_async = function(self, term, search_opts, find_opts)
  local tx, rx = channel.mpsc()
  local found = {}

  local function on_exit(_)
    tx.send(nil)
  end

  ---@param content_match MatchData
  local function on_search_match(content_match)
    local path = vim.fs.normalize(content_match.path.text)
    if not found[path] then
      found[path] = true
      tx.send(path)
    end
  end

  ---@param path_match string
  local function on_find_match(path_match)
    local path = vim.fs.normalize(path_match)
    if not found[path] then
      found[path] = true
      tx.send(path)
    end
  end

  local cmds_done = 0 -- out of the two, one for 'search' and one for 'find'

  search.search_async(
    self.dir,
    term,
    self:_prepare_search_opts(search_opts, { fixed_strings = true, max_count_per_file = 1 }),
    on_search_match,
    on_exit
  )

  search.find_async(self.dir, term, self:_prepare_search_opts(find_opts), on_find_match, on_exit)

  return function()
    while cmds_done < 2 do
      local value = rx.recv()
      if value == nil then
        cmds_done = cmds_done + 1
      else
        return value
      end
    end
    return nil
  end
end

--- Find notes matching the given term. Notes are searched based on ID, title, filename, and aliases.
---
---@param term string The term to search for
---@param opts obsidian.SearchOpts|boolean|? Search options or a boolean indicating if sorting should be done
---@param timeout integer|? Timeout to wait in milliseconds
---
---@return obsidian.Note[]
Client.find_notes = function(self, term, opts, timeout)
  return block_on(function(cb)
    return self:find_notes_async(term, opts, cb)
  end, timeout)
end

--- An async version of `find_notes()` that runs the callback with an array of all matching notes.
---
---@param term string The term to search for
---@param opts obsidian.SearchOpts|boolean|? search options or a boolean indicating if sorting should be used
---@param callback function (obsidian.Note[]) -> nil
Client.find_notes_async = function(self, term, opts, callback)
  local next_path = self:_search_iter_async(term, opts)
  local executor = AsyncExecutor.new()

  local dir = tostring(self.dir)
  local err_count = 0
  local first_err
  local first_err_path

  local function task_fn(path)
    local ok, res = pcall(Note.from_file_async, path, dir)
    if ok then
      return res
    else
      err_count = err_count + 1
      if first_err == nil then
        first_err = res
        first_err_path = path
      end
      return nil
    end
  end

  async.run(function()
    executor:map(task_fn, next_path, function(results)
      -- Check for errors.
      if first_err ~= nil and first_err_path ~= nil then
        log.err(
          "%d error(s) occurred during search. First error from note at '%s':\n%s",
          err_count,
          first_err_path,
          first_err
        )
      end

      -- Filter out error results (nils), and unpack the ok results.
      local results_ = {}
      for res in iter(results) do
        if res[1] ~= nil then
          results_[#results_ + 1] = res[1]
        end
      end

      -- Execute callback.
      callback(results_)
    end)
  end, function(_) end)
end

--- Find non-markdown files in the vault.
---
---@param term string The search term.
---@param opts obsidian.SearchOpts|boolean|? Search options or a boolean indicating if sorting should be done
---@param timeout integer|? Timeout to wait in milliseconds.
---
---@return Path[]
Client.find_files = function(self, term, opts, timeout)
  return block_on(function(cb)
    return self:find_files_async(term, opts, cb)
  end, timeout)
end

--- An async version of `find_files`.
---
---@param term string The search term.
---@param opts obsidian.SearchOpts|boolean|? Search options or a boolean indicating if sorting should be done
---@param callback function (Path[]) -> nil
Client.find_files_async = function(self, term, opts, callback)
  local matches = {}
  local tx, rx = channel.oneshot()
  local on_find_match = function(path_match)
    matches[#matches + 1] = Path:new(vim.fs.normalize(path_match))
  end

  local on_exit = function(_)
    tx()
  end

  local find_opts = self:_prepare_search_opts(opts)
  find_opts:add_exclude "*.md"
  find_opts.include_non_markdown = true

  search.find_async(self.dir, term, find_opts, on_find_match, on_exit)

  async.run(function()
    rx()
    return matches
  end, callback)
end

--- Resolve the query to a single note if possible, otherwise `nil` is returned.
--- The 'query' can be a path, filename, note ID, alias, title, etc.
---
---@param query string
---
---@return obsidian.Note|?
Client.resolve_note = function(self, query, timeout)
  return block_on(function(cb)
    return self:resolve_note_async(query, cb)
  end, timeout)
end

--- An async version of `resolve_note()`.
---
---@param query string
---@param callback function(obsidian.Note|?)
---
---@return obsidian.Note|?
Client.resolve_note_async = function(self, query, callback)
  -- Autocompletion for command args will have this format.
  local note_path, count = string.gsub(query, "^.*  ", "")
  if count > 0 then
    ---@type Path
    ---@diagnostic disable-next-line: assign-type-mismatch
    local full_path = self.dir / note_path
    return async.run(function()
      return Note.from_file_async(full_path, self.dir)
    end, callback)
  end

  -- Query might be a path.
  local fname = query
  if not vim.endswith(fname, ".md") then
    fname = fname .. ".md"
  end

  local paths_to_check = { Path:new(fname), self.dir / fname }

  if self.opts.notes_subdir ~= nil then
    paths_to_check[#paths_to_check + 1] = self.dir / self.opts.notes_subdir / fname
  end

  if self.opts.daily_notes.folder ~= nil then
    paths_to_check[#paths_to_check + 1] = self.dir / self.opts.daily_notes.folder / fname
  end

  if self.buf_dir ~= nil then
    paths_to_check[#paths_to_check + 1] = self.buf_dir / fname
  end

  for _, path in pairs(paths_to_check) do
    if path:is_file() and vim.endswith(tostring(path), ".md") then
      return async.run(function()
        return Note.from_file_async(path)
      end, callback)
    end
  end

  self:find_notes_async(query, { ignore_case = true }, function(results)
    local query_lwr = string.lower(query)
    local maybe_matches = {}
    for note in iter(results) do
      if query == note.id or query == note:display_name() or util.tbl_contains(note.aliases, query) then
        -- Exact match! We're done!
        return callback(note)
      end

      for alias in iter(note.aliases) do
        if query_lwr == string.lower(alias) then
          -- Lower case match, save this one for later.
          table.insert(maybe_matches, note)
          break
        end
      end
    end

    if #maybe_matches > 0 then
      return callback(maybe_matches[1])
    else
      return callback(nil)
    end
  end)
end

--- Find all tags starting with the given term.
---
---@param term string
---@param opts obsidian.SearchOpts|table|boolean|? search options or a boolean indicating if sorting should be used
---@param timeout integer|?
---
---@return string[]
Client.find_tags = function(self, term, opts, timeout)
  return block_on(function(cb)
    return self:find_tags_async(term, opts, cb)
  end, timeout)
end

--- An async version of 'find_tags()'.
---
---@param term string
---@param opts obsidian.SearchOpts|table|boolean|? search options or a boolean indicating if sorting should be used
---@param callback function(string[]) -> nil
Client.find_tags_async = function(self, term, opts, callback)
  assert(string.len(term) > 0)
  term = string.lower(term)

  local tags = {}
  local err_count = 0
  local first_err = nil
  local first_err_path = nil
  local executor = AsyncExecutor.new()

  ---@param match_data MatchData
  local on_content_match = function(match_data)
    local line = match_data.lines.text
    for match in iter(search.find_tags(line)) do
      local m_start, m_end, _ = unpack(match)
      local tag = string.sub(line, m_start + 1, m_end)
      if vim.startswith(string.lower(tag), term) then
        tags[tag] = true
      end
    end
  end

  ---@param match_data MatchData
  local on_frontmatter_match = function(match_data)
    executor:submit(function()
      local path = vim.fs.normalize(match_data.path.text)
      local ok, res = pcall(Note.from_file_async, path, self.dir)
      if ok then
        if res.tags ~= nil then
          for tag in iter(res.tags) do
            tag = tostring(tag)
            if vim.startswith(string.lower(tag), term) then
              tags[tag] = true
            end
          end
        end
      else
        err_count = err_count + 1
        if first_err == nil then
          first_err = res
          first_err_path = path
        end
      end
    end)
  end

  local tx_content, rx_content = channel.oneshot()
  search.search_async(
    self.dir,
    "#" .. term .. search.Patterns.TagChars,
    self:_prepare_search_opts(opts, { ignore_case = true }),
    on_content_match,
    function(_)
      tx_content()
    end
  )

  local tx_frontmatter, rx_frontmatter = channel.oneshot()
  search.search_async(
    self.dir,
    { "\\s*- " .. term .. search.Patterns.TagChars, "tags: .*" .. term .. search.Patterns.TagChars },
    self:_prepare_search_opts(opts, { max_count_per_file = 1, ignore_case = true }),
    on_frontmatter_match,
    function(_)
      tx_frontmatter()
    end
  )

  async.run(function()
    rx_content()
    rx_frontmatter()
    executor:join_async()

    local tags_list = {}
    for tag in iter(tags) do
      tags_list[#tags_list + 1] = tag
    end

    if first_err ~= nil and first_err_path ~= nil then
      log.err(
        "%d error(s) occurred during search. First error from note at '%s':\n%s",
        err_count,
        first_err_path,
        first_err
      )
    end
    return tags_list
  end, callback)
end

--- Apply a function over all notes in the current vault.
---
---@param on_note function (obsidian.Note,) -> nil
---@param on_done function () -> nil
---@param timeout integer|? Timeout in milliseconds.
Client.apply_async = function(self, on_note, on_done, timeout)
  self:apply_async_raw(function(path)
    local ok, res = pcall(Note.from_file_async, path, self.dir)
    if not ok then
      log.warn("Failed to load note at '%s': %s", path, res)
    else
      on_note(res)
    end
  end, on_done, timeout)
end

--- Like apply, but the callback takes a path instead of a note instance.
---
---@param on_path function (string,) -> nil
---@param on_done function () -> nil
---@param timeout integer|? Timeout in milliseconds.
Client.apply_async_raw = function(self, on_path, on_done, timeout)
  local scan = require "plenary.scandir"

  local skip_dirs = {}
  if self.opts.templates ~= nil and self.opts.templates.subdir ~= nil then
    skip_dirs[#skip_dirs + 1] = Path:new(self.opts.templates.subdir)
  end

  local executor = AsyncExecutor.new()

  scan.scan_dir(vim.fs.normalize(tostring(self.dir)), {
    hidden = false,
    add_dirs = false,
    respect_gitignore = true,
    search_pattern = ".*%.md",
    on_insert = function(entry)
      local relative_path = self:vault_relative_path(entry)
      for skip_dir in iter(skip_dirs) do
        if relative_path and vim.startswith(relative_path, tostring(skip_dir) .. skip_dir._sep) then
          return
        end
      end
      executor:submit(on_path, nil, entry)
    end,
  })

  if on_done then
    executor:join_and_then(timeout, on_done)
  else
    executor:join_and_then(timeout, function() end)
  end
end

--- Create a new note ID.
---
---@param title string|?
---
---@return string
Client.new_note_id = function(self, title)
  if self.opts.note_id_func ~= nil then
    local new_id = self.opts.note_id_func(title)
    -- Remote '.md' suffix if it's there (we add that later).
    new_id = new_id:gsub("%.md$", "", 1)
    return new_id
  else
    return util.zettel_id()
  end
end

--- Parse the title, ID, and path for a new note.
---
---@param title string|?
---@param id string|?
---@param dir string|Path|?
---
---@return string|?,string,Path
Client.parse_title_id_path = function(self, title, id, dir)
  ---@type Path
  local base_dir = dir == nil and self.dir or Path:new(dir)
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

--- Create and save a new note.
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
  if new_title ~= nil and new_title:len() > 0 and not util.tbl_contains(aliases, new_title) then
    aliases[#aliases + 1] = new_title
  end

  -- Create Note object and save.
  local note = Note.new(new_id, aliases, {}, path)
  local frontmatter = nil
  if self.opts.note_frontmatter_func ~= nil then
    frontmatter = self.opts.note_frontmatter_func(note)
  end
  note:save(nil, self:should_save_frontmatter(note), frontmatter)
  log.info("Created note " .. tostring(note.id) .. " at " .. tostring(note.path))

  return note
end

--- Get the path to a daily note.
---
---@param datetime integer|?
---
---@return Path, string
Client.daily_note_path = function(self, datetime)
  datetime = datetime and datetime or os.time()

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

  local id
  if self.opts.daily_notes.date_format ~= nil then
    id = tostring(os.date(self.opts.daily_notes.date_format, datetime))
  else
    id = tostring(os.date("%Y-%m-%d", datetime))
  end

  path = path / (id .. ".md")

  return path, id
end

--- Open (or create) the daily note.
---
---@param self obsidian.Client
---@param datetime integer
---
---@return obsidian.Note
---
---@private
Client._daily = function(self, datetime)
  local templates = require "obsidian.templates"

  local path, id = self:daily_note_path(datetime)

  local alias
  if self.opts.daily_notes.alias_format ~= nil then
    alias = tostring(os.date(self.opts.daily_notes.alias_format, datetime))
  else
    alias = tostring(os.date("%B %-d, %Y", datetime))
  end

  -- Create Note object and save if it doesn't already exist.
  local note = Note.new(id, { alias }, { "daily-notes" }, path)
  if not note:exists() then
    local write_frontmatter = true
    if self.opts.daily_notes.template then
      templates.clone_template(self.opts.daily_notes.template, tostring(path), self, note:display_name())
      note = Note.from_file(path, self.dir)
      if note.has_frontmatter then
        write_frontmatter = false
      end
    end
    if write_frontmatter then
      local frontmatter = nil
      if self.opts.note_frontmatter_func ~= nil then
        frontmatter = self.opts.note_frontmatter_func(note)
      end
      note:save(nil, self:should_save_frontmatter(note), frontmatter)
    end
    log.info("Created note " .. tostring(note.id) .. " at " .. tostring(note.path))
  end

  return note
end

--- Open (or create) the daily note for today.
---
---@return obsidian.Note
Client.today = function(self)
  return self:_daily(os.time())
end

--- Open (or create) the daily note from the last weekday.
---
---@return obsidian.Note
Client.yesterday = function(self)
  return self:_daily(util.working_day_before(os.time()))
end

--- Open (or create) the daily note for the next weekday.
---
---@return obsidian.Note
Client.tomorrow = function(self)
  return self:_daily(util.working_day_after(os.time()))
end

--- Open (or create) the daily note for today + `offset_days`.
---
---@param offset_days integer|?
---
---@return obsidian.Note
Client.daily = function(self, offset_days)
  return self:_daily(os.time() + (offset_days * 3600 * 24))
end

Client._run_with_finder_backend = function(self, implementations)
  if self.opts.finder then
    if implementations[self.opts.finder] ~= nil then
      local ok, res = pcall(implementations[self.opts.finder])
      if not ok then
        log.err("error running finder '" .. self.opts.finder .. "':\n" .. tostring(res))
        return
      elseif res == false then
        log.err("unable to load finder '" .. self.opts.finder .. "'. Are you sure it's installed?")
        return
      else
        return res
      end
    else
      log.err("invalid finder '" .. self.opts.finder .. "' in config")
      return
    end
  end

  for finder in iter { "telescope.nvim", "fzf-lua", "fzf.vim", "mini.pick" } do
    if implementations[finder] ~= nil then
      local has_finder, res = implementations[finder]()
      if has_finder then
        return res
      end
    end
  end

  log.err "No finders available. One of 'telescope.nvim', 'fzf-lua', or 'fzf.vim' is required."
end

--- Manually update extmarks in a buffer.
---
---@param bufnr integer|?
Client.update_ui = function(self, bufnr)
  require("obsidian.ui").update(self.opts.ui, bufnr)
end

return Client
