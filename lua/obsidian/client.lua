--- *obsidian-api*
---
--- The Obsidian.nvim Lua API.
---
--- ==============================================================================
---
--- Table of contents
---
---@toc

local Path = require "obsidian.path"
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
local CallbackManager = require("obsidian.callbacks").CallbackManager
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
---@field dir obsidian.Path The root of the vault for the current workspace.
---@field opts obsidian.config.ClientOpts The client config.
---@field buf_dir obsidian.Path|? The parent directory of the current buffer.
---@field callback_manager obsidian.CallbackManager
---@field log obsidian.Logger
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

  self.log = log
  self._default_opts = opts
  self._quiet = false

  local workspace = Workspace.get_from_opts(opts)
  if not workspace then
    error "At least one workspace is required!\nPlease specify a workspace in your Obsidian.nvim config."
  end

  self:set_workspace(workspace)

  return self
end

---@param workspace obsidian.Workspace
---@param opts { lock: boolean|? }|?
Client.set_workspace = function(self, workspace, opts)
  opts = opts and opts or {}
  self.current_workspace = workspace
  self.dir = self:vault_root(workspace)
  self.opts = self:opts_for_workspace(workspace)

  -- Ensure directories exist.
  self.dir:mkdir { parents = true, exists_ok = true }

  if self.opts.notes_subdir ~= nil then
    local notes_subdir = self.dir / self.opts.notes_subdir
    notes_subdir:mkdir { parents = true, exists_ok = true }
  end

  if self.opts.daily_notes.folder ~= nil then
    local daily_notes_subdir = self.dir / self.opts.daily_notes.folder
    daily_notes_subdir:mkdir { parents = true, exists_ok = true }
  end

  -- Initialize callback manager.
  self.callback_manager = CallbackManager.new(self, self.opts.callbacks)

  -- Setup UI add-ons.
  if self.opts.ui.enable then
    require("obsidian.ui").setup(self.current_workspace, self.opts.ui)
  end

  if opts.lock then
    self.current_workspace:lock()
  end

  self.callback_manager:post_set_workspace(workspace)
end

--- Get the normalize opts for a given workspace.
---
---@param workspace obsidian.Workspace|?
---
---@return obsidian.config.ClientOpts
Client.opts_for_workspace = function(self, workspace)
  if workspace then
    return config.ClientOpts.normalize(workspace.overrides and workspace.overrides or {}, self._default_opts)
  else
    return self.opts
  end
end

--- Switch to a different workspace.
---
---@param workspace obsidian.Workspace|string The workspace object or the name of an existing workspace.
---@param opts { lock: boolean|? }|?
Client.switch_workspace = function(self, workspace, opts)
  opts = opts and opts or {}

  if type(workspace) == "string" then
    if workspace == self.current_workspace.name then
      log.info("Already in workspace '%s' @ '%s'", workspace, self.current_workspace.path)
      return
    end

    for _, ws in ipairs(self.opts.workspaces) do
      if ws.name == workspace then
        return self:switch_workspace(Workspace.new_from_spec(ws), opts)
      end
    end

    error(string.format("Workspace '%s' not found", workspace))
  else
    if workspace == self.current_workspace then
      log.info("Already in workspace '%s' @ '%s'", workspace.name, workspace.path)
      return
    end

    log.info("Switching to workspace '%s' @ '%s'", workspace.name, workspace.path)
    self:set_workspace(workspace, opts)
  end
end

--- Check if a path represents a note in the workspace.
---
---@param path string|obsidian.Path
---@param workspace obsidian.Workspace|?
---
---@return boolean
Client.path_is_note = function(self, path, workspace)
  path = Path.new(path):resolve()

  -- Notes have to be markdown file.
  if path.suffix ~= ".md" then
    return false
  end

  -- Ignore markdown files in the templates directory.
  local templates_dir = self:templates_dir(workspace)
  if templates_dir ~= nil then
    if templates_dir:is_parent_of(path) then
      return false
    end
  end

  return true
end

--- Get the absolute path to the root of the Obsidian vault for the given workspace or the
--- current workspace.
---
---@param workspace obsidian.Workspace|?
---
---@return obsidian.Path
Client.vault_root = function(self, workspace)
  workspace = workspace and workspace or self.current_workspace
  return Path.new(workspace.root)
end

--- Get the name of the current vault.
---
---@return string
Client.vault_name = function(self)
  return assert(vim.fs.basename(tostring(self:vault_root())))
end

--- Make a path relative to the vault root, if possible.
---
---@param path string|obsidian.Path
---@param opts { strict: boolean|? }|?
---
---@return obsidian.Path|?
Client.vault_relative_path = function(self, path, opts)
  opts = opts or {}

  -- NOTE: we don't try to resolve the `path` here because that would make the path absolute,
  -- which may result in the wrong relative path if the current working directory is not within
  -- the vault.
  path = Path.new(path)

  local ok, relative_path = pcall(function()
    return path:relative_to(self:vault_root())
  end)

  if ok and relative_path then
    return relative_path
  elseif not path:is_absolute() then
    return path
  elseif opts.strict then
    error(string.format("failed to resolve '%s' relative to vault root '%s'", path, self:vault_root()))
  end
end

--- Get the templates folder.
---
---@param workspace obsidian.Workspace|?
---
---@return obsidian.Path|?
Client.templates_dir = function(self, workspace)
  local opts = self.opts
  if workspace and workspace ~= self.current_workspace then
    opts = self:opts_for_workspace(workspace)
  end

  if opts.templates ~= nil and opts.templates.subdir ~= nil then
    local templates_dir = self:vault_root(workspace) / opts.templates.subdir
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
    return not self.opts.disable_frontmatter(tostring(self:vault_relative_path(note.path, { strict = true })))
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
    local path = Path.new(content_match.path.text):resolve { strict = true }
    if not found[path] then
      found[path] = true
      tx.send(path)
    end
  end

  ---@param path_match string
  local function on_find_match(path_match)
    local path = Path.new(path_match):resolve { strict = true }
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
---@param callback fun(notes: obsidian.Note[])
Client.find_notes_async = function(self, term, opts, callback)
  local next_path = self:_search_iter_async(term, opts)
  local executor = AsyncExecutor.new()

  local err_count = 0
  local first_err
  local first_err_path

  local function task_fn(path)
    local ok, res = pcall(Note.from_file_async, path)
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
---@return obsidian.Path[]
Client.find_files = function(self, term, opts, timeout)
  return block_on(function(cb)
    return self:find_files_async(term, opts, cb)
  end, timeout)
end

--- An async version of `find_files`.
---
---@param term string The search term.
---@param opts obsidian.SearchOpts|boolean|? Search options or a boolean indicating if sorting should be done
---@param callback fun(paths: obsidian.Path[])
Client.find_files_async = function(self, term, opts, callback)
  local matches = {}
  local tx, rx = channel.oneshot()
  local on_find_match = function(path_match)
    matches[#matches + 1] = Path.new(path_match)
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
---@param callback fun(note: obsidian.Note|?)
---
---@return obsidian.Note|?
Client.resolve_note_async = function(self, query, callback)
  -- Autocompletion for command args will have this format.
  local note_path, count = string.gsub(query, "^.*  ", "")
  if count > 0 then
    ---@type obsidian.Path
    ---@diagnostic disable-next-line: assign-type-mismatch
    local full_path = self.dir / note_path
    return async.run(function()
      return Note.from_file_async(full_path)
    end, callback)
  end

  -- Query might be a path.
  local fname = query
  if not vim.endswith(fname, ".md") then
    fname = fname .. ".md"
  end

  local paths_to_check = { Path.new(fname), self.dir / fname }

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
    if path:is_file() then
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

---@class obsidian.ResolveLinkResult
---
---@field location string
---@field name string
---@field link_type obsidian.search.RefTypes
---@field path obsidian.Path|?
---@field note obsidian.Note|?
---@field url string|?

--- Resolve a link. If the link argument is `nil` we attempt to resolve a link under the cursor.
---
---@param link string|?
---@param callback fun(res: obsidian.ResolveLinkResult|?)
Client.resolve_link_async = function(self, link, callback)
  local location, name, link_type
  if link then
    location, name, link_type = util.parse_link(link, { include_naked_urls = true, include_file_urls = true })
  else
    location, name, link_type = util.parse_cursor_link { include_naked_urls = true, include_file_urls = true }
  end

  if location == nil or name == nil or link_type == nil then
    return callback(nil)
  end

  ---@type obsidian.ResolveLinkResult
  local res = { location = location, name = name, link_type = link_type }

  if util.is_url(location) then
    res.url = location
    return callback(res)
  end

  -- The Obsidian app will follow links with spaces encoded as "%20" (as they are in URLs),
  -- so we should too.
  location = util.string_replace(location, "%20", " ")

  -- Remove links from the end if there are any.
  local header_link = location:match "#[%a%d%s-_^]+$"
  if header_link ~= nil then
    location = location:sub(1, -header_link:len() - 1)
  end

  res.location = location

  self:resolve_note_async(location, function(note)
    if note ~= nil then
      res.path = note.path
      res.note = note
      return callback(res)
    end

    local path = Path.new(location)
    if path:exists() then
      res.path = path
      return callback(res)
    end

    return callback(res)
  end)
end

--- Follow a link. If the link argument is `nil` we attempt to follow a link under the cursor.
---
---@param link string|?
---@param opts { open_strategy: obsidian.config.OpenStrategy|? }|?
Client.follow_link_async = function(self, link, opts)
  opts = opts and opts or {}
  self:resolve_link_async(link, function(res)
    if res == nil then
      return
    end

    if res.url ~= nil then
      if self.opts.follow_url_func ~= nil then
        self.opts.follow_url_func(res.url)
      else
        log.warn "This looks like a URL. You can customize the behavior of URLs with the 'follow_url_func' option."
      end
      return
    end

    if res.note ~= nil then
      -- Go to resolved note.
      return vim.schedule(function()
        self:open_note(res.note, { open_strategy = opts.open_strategy })
      end)
    end

    if res.link_type == search.RefTypes.Wiki or res.link_type == search.RefTypes.WikiWithAlias then
      -- Prompt to create a new note.
      return vim.schedule(function()
        local confirmation = string.lower(vim.fn.input {
          prompt = "Create new note '" .. res.location .. "'? [Y/n] ",
        })
        if confirmation == "" or confirmation == "y" or confirmation == "yes" then
          -- Create a new note.
          ---@type string|?, string[]
          local id, aliases
          if res.name == res.location then
            aliases = {}
          else
            aliases = { res.name }
            id = res.location
          end

          local note = self:create_note { title = res.name, id = id, aliases = aliases }
          self:open_note(note, { open_strategy = opts.open_strategy })
        else
          log.warn "Aborting"
        end
      end)
    end

    return log.err("Failed to resolve file '" .. res.location .. "'")
  end)
end

--- Open a note in a buffer.
---
---@param note_or_path string|obsidian.Path|obsidian.Note
---@param opts { line: integer|?, col: integer|?, open_strategy: obsidian.config.OpenStrategy|? }|?
Client.open_note = function(self, note_or_path, opts)
  opts = opts and opts or {}

  ---@type obsidian.Path
  local path
  if type(note_or_path) == "string" then
    path = Path.new(note_or_path)
  elseif type(note_or_path) == "table" and note_or_path.path ~= nil then
    -- this is a Note
    ---@cast note_or_path obsidian.Note
    path = note_or_path.path
  elseif type(note_or_path) == "table" and note_or_path.filename ~= nil then
    -- this is a Path
    ---@cast note_or_path obsidian.Path
    path = note_or_path
  else
    error "invalid 'note_or_path' argument"
  end

  local open_cmd = util.get_open_strategy(opts.open_strategy and opts.open_strategy or self.opts.open_notes_in)
  ---@cast path obsidian.Path
  util.open_buffer(path, { line = opts.line, col = opts.col, cmd = open_cmd })
end

--- Get the current note from a buffer.
---
---@param bufnr integer|?
---
---@return obsidian.Note|?
---@diagnostic disable-next-line: unused-local
Client.current_note = function(self, bufnr)
  bufnr = bufnr or 0
  if not self:path_is_note(vim.api.nvim_buf_get_name(bufnr)) then
    return nil
  end

  return Note.from_buffer(bufnr)
end

---@class obsidian.TagLocation
---
---@field tag string The tag found.
---@field note obsidian.Note The note instance where the tag was found.
---@field path string|obsidian.Path The path to the note where the tag was found.
---@field line integer The line number (1-indexed) where the tag was found.
---@field text string The text (with whitespace stripped) of the line where the tag was found.
---@field tag_start integer|? The index within 'text' where the tag starts.
---@field tag_end integer|? The index within 'text' where the tag ends.

--- Find all tags starting with the given search term(s).
---
---@param term string|string[] The search term.
---@param opts obsidian.SearchOpts|boolean|? Search options or a boolean indicating if sorting should be used.
---@param timeout integer|? Timeout in milliseconds.
---
---@return obsidian.TagLocation[]
Client.find_tags = function(self, term, opts, timeout)
  return block_on(function(cb)
    return self:find_tags_async(term, opts, cb)
  end, timeout)
end

--- An async version of 'find_tags()'.
---
---@param term string|string[] The search term.
---@param opts obsidian.SearchOpts|boolean|? Search options or a boolean indicating if sorting should be used.
---@param callback fun(tags: obsidian.TagLocation[])
Client.find_tags_async = function(self, term, opts, callback)
  ---@type string[]
  local terms
  if type(term) == "string" then
    terms = { term }
  else
    terms = term
  end

  for i, t in ipairs(terms) do
    if vim.startswith(t, "#") then
      terms[i] = string.sub(t, 2)
    end
  end

  terms = util.tbl_unique(terms)

  -- Maps paths to tag locations.
  ---@type table<obsidian.Path, obsidian.TagLocation[]>
  local path_to_tag_loc = {}
  -- Caches note objects.
  ---@type table<obsidian.Path, obsidian.Note>
  local path_to_note = {}
  -- Caches code block locations.
  ---@type table<obsidian.Path, { [1]: integer, [2]: integer []}>
  local path_to_code_blocks = {}
  -- Keeps track of the order of the paths.
  ---@type table<string, integer>
  local path_order = {}

  local num_paths = 0
  local err_count = 0
  local first_err = nil
  local first_err_path = nil

  local executor = AsyncExecutor.new()

  ---@param tag string
  ---@param path string|obsidian.Path
  ---@param note obsidian.Note
  ---@param lnum integer
  ---@param text string
  ---@param col_start integer|?
  ---@param col_end integer|?
  local add_match = function(tag, path, note, lnum, text, col_start, col_end)
    if not path_to_tag_loc[path] then
      path_to_tag_loc[path] = {}
    end
    path_to_tag_loc[path][#path_to_tag_loc[path] + 1] = {
      tag = tag,
      path = path,
      note = note,
      line = lnum,
      text = text,
      tag_start = col_start,
      tag_end = col_end,
    }
  end

  -- Wraps `Note.from_file_with_contents_async()` to return a table instead of a tuple and
  -- find the code blocks.
  ---@param path obsidian.Path
  ---@return { [1]: obsidian.Note, [2]: {[1]: integer, [2]: integer}[] }
  local load_note = function(path)
    local note, contents = Note.from_file_with_contents_async(path)
    return { note, search.find_code_blocks(contents) }
  end

  ---@param match_data MatchData
  local on_match = function(match_data)
    local path = Path.new(match_data.path.text):resolve { strict = true }

    if path_order[path] == nil then
      num_paths = num_paths + 1
      path_order[path] = num_paths
    end

    executor:submit(function()
      -- Load note.
      local note = path_to_note[path]
      local code_blocks = path_to_code_blocks[path]
      if not note or not code_blocks then
        local ok, res = pcall(load_note, path)
        if ok then
          note, code_blocks = unpack(res)
          path_to_note[path] = note
          path_to_code_blocks[path] = code_blocks
        else
          err_count = err_count + 1
          if first_err == nil then
            first_err = res
            first_err_path = path
          end
          return
        end
      end

      -- check if the match was inside a code block.
      for block in iter(code_blocks) do
        if block[1] <= match_data.line_number and match_data.line_number <= block[2] then
          return
        end
      end

      local line = util.strip_whitespace(match_data.lines.text)
      local n_matches = 0

      -- check for tag in the wild of the form '#{tag}'
      for match in iter(search.find_tags(line)) do
        local m_start, m_end, _ = unpack(match)
        local tag = string.sub(line, m_start + 1, m_end)
        if string.match(tag, "^" .. search.Patterns.TagCharsRequired .. "$") then
          add_match(tag, path, note, match_data.line_number, line, m_start, m_end)
        end
      end

      -- check for tags in frontmatter
      if n_matches == 0 and note.tags ~= nil and (vim.startswith(line, "tags:") or string.match(line, "%s*- ")) then
        for tag in iter(note.tags) do
          tag = tostring(tag)
          for _, t in ipairs(terms) do
            if string.len(t) == 0 or util.string_contains(tag, t) then
              add_match(tag, path, note, match_data.line_number, line)
            end
          end
        end
      end
    end)
  end

  local tx, rx = channel.oneshot()

  local search_terms = {}
  for t in iter(terms) do
    if string.len(t) > 0 then
      -- tag in the wild
      search_terms[#search_terms + 1] = "#" .. search.Patterns.TagCharsOptional .. t .. search.Patterns.TagCharsOptional
      -- frontmatter tag in multiline list
      search_terms[#search_terms + 1] = "\\s*- "
        .. search.Patterns.TagCharsOptional
        .. t
        .. search.Patterns.TagCharsOptional
        .. "$"
      -- frontmatter tag in inline list
      search_terms[#search_terms + 1] = "tags: .*"
        .. search.Patterns.TagCharsOptional
        .. t
        .. search.Patterns.TagCharsOptional
    else
      -- tag in the wild
      search_terms[#search_terms + 1] = "#" .. search.Patterns.TagCharsRequired
      -- frontmatter tag in multiline list
      search_terms[#search_terms + 1] = "\\s*- " .. search.Patterns.TagCharsRequired .. "$"
      -- frontmatter tag in inline list
      search_terms[#search_terms + 1] = "tags: .*" .. search.Patterns.TagCharsRequired
    end
  end

  search.search_async(
    self.dir,
    search_terms,
    self:_prepare_search_opts(opts, { ignore_case = true }),
    on_match,
    function(_)
      tx()
    end
  )

  async.run(function()
    rx()
    executor:join_async()

    ---@type obsidian.TagLocation[]
    local tags_list = {}

    -- Order by path.
    local paths = {}
    for path, idx in pairs(path_order) do
      paths[idx] = path
    end

    -- Gather results in path order.
    for _, path in ipairs(paths) do
      local tag_locs = path_to_tag_loc[path]
      if tag_locs ~= nil then
        table.sort(tag_locs, function(a, b)
          return a.line < b.line
        end)
        for _, tag_loc in ipairs(tag_locs) do
          tags_list[#tags_list + 1] = tag_loc
        end
      end
    end

    -- Log any errors.
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

---@class obsidian.BacklinkMatches
---
---@field note obsidian.Note The note instance where the backlinks were found.
---@field path string|obsidian.Path The path to the note where the backlinks were found.
---@field matches obsidian.BacklinkMatch[] The backlinks within the note.

---@class obsidian.BacklinkMatch
---
---@field line integer The line number (1-indexed) where the backlink was found.
---@field text string The text of the line where the backlink was found.

--- Find all backlinks to a note.
---
---@param note obsidian.Note The note to find backlinks for.
---@param opts obsidian.SearchOpts|boolean|? Search options or a boolean indicating if sorting should be used.
---@param timeout integer|? Timeout in milliseconds.
---
---@return obsidian.BacklinkMatches[]
Client.find_backlinks = function(self, note, opts, timeout)
  return block_on(function(cb)
    return self:find_backlinks_async(note, opts, cb)
  end, timeout)
end

--- An async version of 'find_backlinks()'.
---
---@param note obsidian.Note The note to find backlinks for.
---@param opts obsidian.SearchOpts|boolean|? Search options or a boolean indicating if sorting should be used.
---@param callback fun(backlinks: obsidian.BacklinkMatches[])
Client.find_backlinks_async = function(self, note, opts, callback)
  -- Maps paths (string) to note object and a list of matches.
  ---@type table<string, obsidian.BacklinkMatch[]>
  local backlink_matches = {}
  ---@type table<string, obsidian.Note>
  local path_to_note = {}
  -- Keeps track of the order of the paths.
  ---@type table<string, integer>
  local path_order = {}
  local num_paths = 0
  local err_count = 0
  local first_err = nil
  local first_err_path = nil

  local executor = AsyncExecutor.new()

  -- Prepare search terms.
  local search_terms = {}
  for ref in iter { tostring(note.id), note:fname() } do
    if ref ~= nil then
      search_terms[#search_terms + 1] = string.format("[[%s]]", ref)
      search_terms[#search_terms + 1] = string.format("[[%s|", ref)
      search_terms[#search_terms + 1] = string.format("(%s)", ref)
    end
  end
  for alias in iter(note.aliases) do
    search_terms[#search_terms + 1] = string.format("[[%s]]", alias)
  end

  local function on_match(match)
    local path = Path.new(match.path.text):resolve { strict = true }

    if path_order[path] == nil then
      num_paths = num_paths + 1
      path_order[path] = num_paths
    end

    executor:submit(function()
      -- Load note.
      local n = path_to_note[path]
      if not n then
        local ok, res = pcall(Note.from_file_async, path)
        if ok then
          n = res
          path_to_note[path] = n
        else
          err_count = err_count + 1
          if first_err == nil then
            first_err = res
            first_err_path = path
          end
          return
        end
      end

      ---@type obsidian.BacklinkMatch[]
      local line_matches = backlink_matches[path]
      if line_matches == nil then
        line_matches = {}
        backlink_matches[path] = line_matches
      end

      line_matches[#line_matches + 1] = {
        line = match.line_number,
        text = util.rstrip_whitespace(match.lines.text),
      }
    end)
  end

  local tx, rx = channel.oneshot()

  -- Execute search.
  search.search_async(
    self.dir,
    util.tbl_unique(search_terms),
    self:_prepare_search_opts(opts, { fixed_strings = true }),
    on_match,
    function()
      tx()
    end
  )

  async.run(function()
    rx()
    executor:join_async()

    ---@type obsidian.BacklinkMatches[]
    local results = {}

    -- Order by path.
    local paths = {}
    for path, idx in pairs(path_order) do
      paths[idx] = path
    end

    -- Gather results.
    for i, path in ipairs(paths) do
      results[i] = { note = path_to_note[path], path = path, matches = backlink_matches[path] }
    end

    -- Log any errors.
    if first_err ~= nil and first_err_path ~= nil then
      log.err(
        "%d error(s) occurred during search. First error from note at '%s':\n%s",
        err_count,
        first_err_path,
        first_err
      )
    end

    return results
  end, callback)
end

--- Gather a list of all tags in the vault. If 'term' is provided, only tags that partially match the search
--- term will be included.
---
---@param term string|? An optional search term to match tags
---@param timeout integer|? Timeout in milliseconds
---
---@return string[]
Client.list_tags = function(self, term, timeout)
  local tags = {}
  for _, tag_loc in ipairs(self:find_tags(term and term or "", nil, timeout)) do
    tags[tag_loc.tag] = true
  end
  return vim.tbl_keys(tags)
end

--- An async version of 'list_tags()'.
---
---@param term string|?
---@param callback fun(tags: string[])
Client.list_tags_async = function(self, term, callback)
  self:find_tags_async(term and term or "", nil, function(tag_locations)
    local tags = {}
    for _, tag_loc in ipairs(tag_locations) do
      tags[tag_loc.tag] = true
    end
    callback(vim.tbl_keys(tags))
  end)
end

--- Apply a function over all notes in the current vault.
---
---@param on_note fun(note: obsidian.Note)
---@param opts { on_done: fun()|?, timeout: integer|?, pattern: string|? }|?
---
--- Options:
---  - `on_done`: A function to call when all notes have been processed.
---  - `timeout`: An optional timeout.
---  - `pattern`: A Lua search pattern. Defaults to ".*%.md".
Client.apply_async = function(self, on_note, opts)
  self:apply_async_raw(function(path)
    local ok, res = pcall(Note.from_file_async, path)
    if not ok then
      log.warn("Failed to load note at '%s': %s", path, res)
    else
      on_note(res)
    end
  end, opts)
end

--- Like apply, but the callback takes a path instead of a note instance.
---
---@param on_path fun(path: string)
---@param opts { on_done: fun()|?, timeout: integer|?, pattern: string|? }|?
---
--- Options:
---  - `on_done`: A function to call when all paths have been processed.
---  - `timeout`: An optional timeout.
---  - `pattern`: A Lua search pattern. Defaults to ".*%.md".
Client.apply_async_raw = function(self, on_path, opts)
  local scan = require "plenary.scandir"
  opts = opts or {}

  local skip_dirs = {}
  local templates_dir = self:templates_dir()
  if templates_dir ~= nil then
    skip_dirs[#skip_dirs + 1] = templates_dir
  end

  local executor = AsyncExecutor.new()

  scan.scan_dir(tostring(self.dir), {
    hidden = false,
    add_dirs = false,
    respect_gitignore = true,
    search_pattern = opts.pattern or ".*%.md",
    on_insert = function(entry)
      entry = Path.new(entry):resolve { strict = true }

      if entry.suffix ~= ".md" then
        return
      end

      for skip_dir in iter(skip_dirs) do
        if skip_dir:is_parent_of(entry) then
          return
        end
      end

      executor:submit(on_path, nil, tostring(entry))
    end,
  })

  if opts.on_done then
    executor:join_and_then(opts.timeout, opts.on_done)
  else
    executor:join_and_then(opts.timeout, function() end)
  end
end

--- Generate a unique ID for a new note. This respects the user's `note_id_func` if configured,
--- otherwise falls back to generated a Zettelkasten style ID.
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

--- Generate the file path for a new note given its ID, parent directory, and title.
--- This respects the user's `note_path_func` if configured, otherwise essentially falls back to
--- `spec.dir / (spec.id .. ".md")`.
---
---@param spec { id: string, dir: obsidian.Path, title: string|? }
---
---@return obsidian.Path
Client.new_note_path = function(self, spec)
  ---@type obsidian.Path
  local path
  if self.opts.note_path_func ~= nil then
    path = Path.new(self.opts.note_path_func(spec))
    -- Ensure path is either absolute or inside `spec.dir`.
    -- NOTE: `spec.dir` should always be absolute, but for extra safety we handle the case where
    -- it's not.
    if not path:is_absolute() and (spec.dir:is_absolute() or not spec.dir:is_parent_of(path)) then
      path = spec.dir / path
    end
  else
    path = spec.dir / tostring(spec.id)
  end
  return path:with_suffix ".md"
end

--- Parse the title, ID, and path for a new note.
---
---@param title string|?
---@param id string|?
---@param dir string|obsidian.Path|?
---
---@return string|?,string,obsidian.Path
Client.parse_title_id_path = function(self, title, id, dir)
  if title then
    title = util.strip_whitespace(title)
    if title == "" then
      title = nil
    end
  end

  if id then
    id = util.strip_whitespace(id)
    if id == "" then
      id = nil
    end
  end

  ---@param s string
  ---@param strict_paths_only boolean
  ---@return string|?, boolean, string|?
  local parse_as_path = function(s, strict_paths_only)
    local is_path = false
    ---@type string|?
    local parent

    if s:match "%.md" then
      -- Remove suffix.
      s = s:sub(1, s:len() - 3)
      is_path = true
    end

    -- Pull out any parent dirs from title.
    local parts = vim.split(s, "/")
    if #parts > 1 then
      s = parts[#parts]
      if not strict_paths_only then
        is_path = true
      end
      parent = table.concat(parts, "/", 1, #parts - 1)
    end

    if s == "" then
      return nil, is_path, parent
    else
      return s, is_path, parent
    end
  end

  local parent, _, title_is_path
  if id then
    id, _, parent = parse_as_path(id, false)
  elseif title then
    title, title_is_path, parent = parse_as_path(title, true)
    if title_is_path then
      id = title
    end
  end

  -- Resolve base directory.
  ---@type obsidian.Path
  local base_dir
  if parent then
    base_dir = self.dir / parent
  elseif dir ~= nil then
    base_dir = Path.new(dir)
    if not base_dir:is_absolute() then
      base_dir = self.dir / base_dir
    else
      base_dir = base_dir:resolve { strict = true }
    end
  else
    local bufpath = Path.buffer(0):resolve()
    if
      self.opts.new_notes_location == config.NewNotesLocation.current_dir
      -- note is actually in the workspace.
      and self.dir:is_parent_of(bufpath)
      -- note is not in dailies folder
      and (self.opts.daily_notes.folder == nil or not (self.dir / self.opts.daily_notes.folder):is_parent_of(bufpath))
    then
      base_dir = self.buf_dir or assert(bufpath:parent())
    else
      base_dir = self.dir
      if self.opts.notes_subdir then
        base_dir = base_dir / self.opts.notes_subdir
      end
    end
  end

  -- Make sure `base_dir` is absolute at this point.
  assert(base_dir:is_absolute(), ("failed to resolve note directory '%s'"):format(base_dir))

  -- Generate new ID if needed.
  if not id then
    id = self:new_note_id(title)
  end

  -- Generate path.
  ---@type obsidian.Path
  ---@diagnostic disable-next-line: assign-type-mismatch
  local path = self:new_note_path { id = id, dir = base_dir, title = title }

  return title, id, path
end

--- Create and save a new note.
--- Deprecated: prefer `Client:create_note()` instead.
---
---@param title string|? The title for the note.
---@param id string|? An optional ID for the note. If not provided one will be generated.
---@param dir string|obsidian.Path|? An optional directory to place the note. If this is a relative path it will be interpreted relative the workspace / vault root.
---@param aliases string[]|? Additional aliases to assign to the note.
---
---@return obsidian.Note
---@deprecated
Client.new_note = function(self, title, id, dir, aliases)
  return self:create_note { title = title, id = id, dir = dir, aliases = aliases }
end

--- Create a new note with the following options.
---
---@param opts { title: string|?, id: string|?, dir: string|obsidian.Path|?, aliases: string[]|?, tags: string[]|?, no_write: boolean|? }|? Options.
---
--- Options:
---  - `title`: A title to assign the note.
---  - `id`: An ID to assign the note. If not specified one will be generated.
---  - `dir`: An optional directory to place the note in. Relative paths will be interpreted
---    relative to the workspace / vault root.
---  - `aliases`: Additional aliases to assign to the note.
---  - `tags`: Additional tags to assign to the note.
---  - `no_write`: Don't write the note to disk.
---
---@return obsidian.Note
Client.create_note = function(self, opts)
  opts = opts or {}

  local new_title, new_id, path = self:parse_title_id_path(opts.title, opts.id, opts.dir)

  -- Add title as an alias.
  ---@type string[]
  ---@diagnostic disable-next-line: assign-type-mismatch
  local aliases = opts.aliases or {}
  if new_title ~= nil and new_title:len() > 0 and not util.tbl_contains(aliases, new_title) then
    aliases[#aliases + 1] = new_title
  end

  -- Create `Note` object.
  local note = Note.new(new_id, aliases, opts.tags or {}, path)
  if opts.title then
    note.title = opts.title
  end

  -- Write to disk.
  if not opts.no_write then
    self:write_note(note)
  end

  return note
end

--- Write the note to disk.
---
---@param note obsidian.Note
---@param opts { path: string|obsidian.Path, update_content: (fun(lines: string[]): string[])|? }|? Options.
---
--- Options:
---  - `path`: Override the path to write to.
---  - `update_content`: A function to update the contents of the note. This takes a list of lines
---    representing the text to be written excluding frontmatter, and returns the lines that will
---    actually be written (again excluding frontmatter).
Client.write_note = function(self, note, opts)
  opts = opts or {}
  local path = assert(opts.path or note.path, "A path must be provided")
  path = Path.new(path)

  local frontmatter = nil
  if self.opts.note_frontmatter_func ~= nil then
    frontmatter = self.opts.note_frontmatter_func(note)
  end

  local verb = path:is_file() and "Updated" or "Created"

  note:save {
    path = path,
    insert_frontmatter = self:should_save_frontmatter(note),
    frontmatter = frontmatter,
    update_content = opts.update_content,
  }

  log.info("%s note '%s' at '%s'", verb, note.id, self:vault_relative_path(note.path) or note.path)
end

--- Update the frontmatter in a buffer for the note.
---
---@param note obsidian.Note
---@param bufnr integer|?
---
---@return boolean updated If the the frontmatter was updated.
Client.update_frontmatter = function(self, note, bufnr)
  local frontmatter = nil
  if self.opts.note_frontmatter_func ~= nil then
    frontmatter = self.opts.note_frontmatter_func(note)
  end
  return note:save_to_buffer(bufnr, frontmatter)
end

--- Get the path to a daily note.
---
---@param datetime integer|?
---
---@return obsidian.Path, string
Client.daily_note_path = function(self, datetime)
  datetime = datetime and datetime or os.time()

  ---@type obsidian.Path
  local path = Path:new(self.dir)

  if self.opts.daily_notes.folder ~= nil then
    ---@type obsidian.Path
    ---@diagnostic disable-next-line: assign-type-mismatch
    path = path / self.opts.daily_notes.folder
  elseif self.opts.notes_subdir ~= nil then
    ---@type obsidian.Path
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
      templates.clone_template(self.opts.daily_notes.template, path, self, note:display_name())
      note = Note.from_file(path)
      if note.has_frontmatter then
        write_frontmatter = false
      end
    end

    if write_frontmatter then
      local frontmatter = nil
      if self.opts.note_frontmatter_func ~= nil then
        frontmatter = self.opts.note_frontmatter_func(note)
      end
      note:save { insert_frontmatter = self:should_save_frontmatter(note), frontmatter = frontmatter }
    end

    log.info("Created daily note '%s' at '%s'", note.id, self:vault_relative_path(note.path) or note.path)
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

--- Manually update extmarks in a buffer.
---
---@param bufnr integer|?
Client.update_ui = function(self, bufnr)
  require("obsidian.ui").update(self.opts.ui, bufnr)
end

--- Create a formatted markdown / wiki link for a note.
---
---@param note obsidian.Note|obsidian.Path|string The note/path to link to.
---@param opts { label: string|?, link_style: obsidian.config.LinkStyle|?, id: string|integer|? }|? Options.
---
---@return string
Client.format_link = function(self, note, opts)
  opts = opts and opts or {}

  ---@type string, string, string|integer|?
  local rel_path, label, note_id
  if type(note) == "string" or Path.is_path_obj(note) then
    ---@cast note string|obsidian.Path
    rel_path = tostring(self:vault_relative_path(note, { strict = true }))
    label = opts.label or tostring(note)
    note_id = opts.id
  else
    ---@cast note obsidian.Note
    rel_path = tostring(self:vault_relative_path(note.path, { strict = true }))
    label = opts.label or note:display_name()
    note_id = opts.id or note.id
  end

  local link_style = opts.link_style
  if link_style == nil then
    link_style = self.opts.preferred_link_style
  end

  local new_opts = { path = rel_path, label = label, id = note_id }

  if link_style == config.LinkStyle.markdown then
    return self.opts.markdown_link_func(new_opts)
  elseif link_style == config.LinkStyle.wiki or link_style == nil then
    return self.opts.wiki_link_func(new_opts)
  else
    error(string.format("Invalid link style '%s'", link_style))
  end
end

--- Get the Picker.
---
---@param picker_name obsidian.config.Picker|?
---
---@return obsidian.Picker|?
Client.picker = function(self, picker_name)
  return require("obsidian.pickers").get(self, picker_name)
end

return Client
