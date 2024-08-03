local Path = require "obsidian.path"
local File = require("obsidian.async").File
local abc = require "obsidian.abc"
local with = require("plenary.context_manager").with
local open = require("plenary.context_manager").open
local yaml = require "obsidian.yaml"
local log = require "obsidian.log"
local util = require "obsidian.util"
local search = require "obsidian.search"
local iter = require("obsidian.itertools").iter
local enumerate = require("obsidian.itertools").enumerate
local compat = require "obsidian.compat"

local SKIP_UPDATING_FRONTMATTER = { "README.md", "CONTRIBUTING.md", "CHANGELOG.md" }

local DEFAULT_MAX_LINES = 500

local CODE_BLOCK_PATTERN = "^%s*```[%w_-]*$"

---@class obsidian.note.HeaderAnchor
---
---@field anchor string
---@field header string
---@field level integer
---@field line integer
---@field parent obsidian.note.HeaderAnchor|?

---@class obsidian.note.Block
---
---@field id string
---@field line integer
---@field block string

--- A class that represents a note within a vault.
---
---@toc_entry obsidian.Note
---
---@class obsidian.Note : obsidian.ABC
---
---@field id string|integer
---@field aliases string[]
---@field title string|?
---@field tags string[]
---@field path obsidian.Path|?
---@field metadata table|?
---@field has_frontmatter boolean|?
---@field frontmatter_end_line integer|?
---@field contents string[]|?
---@field anchor_links table<string, obsidian.note.HeaderAnchor>|?
---@field blocks table<string, obsidian.note.Block>?
---@field alt_alias string|?
---@field bufnr integer|?
local Note = abc.new_class {
  __tostring = function(self)
    return string.format("Note('%s')", self.id)
  end,
}

Note.is_note_obj = function(note)
  if getmetatable(note) == Note.mt then
    return true
  else
    return false
  end
end

--- Create new note object.
---
--- Keep in mind that you have to call `note:save(...)` to create/update the note on disk.
---
---@param id string|number
---@param aliases string[]
---@param tags string[]
---@param path string|obsidian.Path|?
---
---@return obsidian.Note
Note.new = function(id, aliases, tags, path)
  local self = Note.init()
  self.id = id
  self.aliases = aliases and aliases or {}
  self.tags = tags and tags or {}
  self.path = path and Path.new(path) or nil
  self.metadata = nil
  self.has_frontmatter = nil
  self.frontmatter_end_line = nil
  return self
end

--- Get markdown display info about the note.
---
---@param opts { label: string|?, anchor: obsidian.note.HeaderAnchor|?, block: obsidian.note.Block|? }|?
---
---@return string
Note.display_info = function(self, opts)
  opts = opts and opts or {}

  ---@type string[]
  local info = {}

  if opts.label ~= nil and string.len(opts.label) > 0 then
    info[#info + 1] = ("%s"):format(opts.label)
    info[#info + 1] = "--------"
  end

  if self.path ~= nil then
    info[#info + 1] = ("**path:** `%s`"):format(self.path)
  end

  info[#info + 1] = ("**id:** `%s`"):format(self.id)

  if #self.aliases > 0 then
    info[#info + 1] = ("**aliases:** '%s'"):format(table.concat(self.aliases, "', '"))
  end

  if #self.tags > 0 then
    info[#info + 1] = ("**tags:** `#%s`"):format(table.concat(self.tags, "`, `#"))
  end

  if opts.anchor or opts.block then
    info[#info + 1] = "--------"

    if opts.anchor then
      info[#info + 1] = ("...\n%s %s\n..."):format(string.rep("#", opts.anchor.level), opts.anchor.header)
    elseif opts.block then
      info[#info + 1] = ("...\n%s\n..."):format(opts.block.block)
    end
  end

  return table.concat(info, "\n")
end

--- Check if the note exists on the file system.
---
---@return boolean
Note.exists = function(self)
  ---@diagnostic disable-next-line: return-type-mismatch
  return self.path ~= nil and self.path:is_file()
end

--- Get the filename associated with the note.
---
---@return string|?
Note.fname = function(self)
  if self.path == nil then
    return nil
  else
    return vim.fs.basename(tostring(self.path))
  end
end

--- Get a list of all of the different string that can identify this note via references,
--- including the ID, aliases, and filename.
---@param opts { lowercase: boolean|? }|?
---@return string[]
Note.reference_ids = function(self, opts)
  opts = opts or {}
  ---@type string[]
  local ref_ids = { tostring(self.id), self:display_name() }
  if self.path then
    table.insert(ref_ids, self.path.name)
    table.insert(ref_ids, self.path.stem)
  end

  vim.list_extend(ref_ids, self.aliases)

  if opts.lowercase then
    ref_ids = vim.tbl_map(string.lower, ref_ids)
  end

  return util.tbl_unique(ref_ids)
end

Note.should_save_frontmatter = function(self)
  local fname = self:fname()
  return (fname ~= nil and not util.tbl_contains(SKIP_UPDATING_FRONTMATTER, fname))
end

--- Check if a note has a given alias.
---
---@param alias string
---
---@return boolean
Note.has_alias = function(self, alias)
  return util.tbl_contains(self.aliases, alias)
end

--- Check if a note has a given tag.
---
---@param tag string
---
---@return boolean
Note.has_tag = function(self, tag)
  return util.tbl_contains(self.tags, tag)
end

--- Add an alias to the note.
---
---@param alias string
---
---@return boolean added True if the alias was added, false if it was already present.
Note.add_alias = function(self, alias)
  if not self:has_alias(alias) then
    table.insert(self.aliases, alias)
    return true
  else
    return false
  end
end

--- Add a tag to the note.
---
---@param tag string
---
---@return boolean added True if the tag was added, false if it was already present.
Note.add_tag = function(self, tag)
  if not self:has_tag(tag) then
    table.insert(self.tags, tag)
    return true
  else
    return false
  end
end

--- Add or update a field in the frontmatter.
---
---@param key string
---@param value any
Note.add_field = function(self, key, value)
  if key == "id" or key == "aliases" or key == "tags" then
    error "Updating field '%s' this way is not allowed. Please update the corresponding attribute directly instead"
  end

  if not self.metadata then
    self.metadata = {}
  end

  self.metadata[key] = value
end

--- Get a field in the frontmatter.
---
---@param key string
---
---@return any result
Note.get_field = function(self, key)
  if key == "id" or key == "aliases" or key == "tags" then
    error "Getting field '%s' this way is not allowed. Please use the corresponding attribute directly instead"
  end

  if not self.metadata then
    return nil
  end

  return self.metadata[key]
end

---@class obsidian.note.LoadOpts
---@field max_lines integer|?
---@field load_contents boolean|?
---@field collect_anchor_links boolean|?
---@field collect_blocks boolean|?

--- Initialize a note from a file.
---
---@param path string|obsidian.Path
---@param opts obsidian.note.LoadOpts|?
---
---@return obsidian.Note
Note.from_file = function(path, opts)
  if path == nil then
    error "note path cannot be nil"
  end
  local n
  with(open(tostring(Path.new(path):resolve { strict = true })), function(reader)
    n = Note.from_lines(reader:lines(), path, opts)
  end)
  return n
end

--- An async version of `.from_file()`, i.e. it needs to be called in an async context.
---
---@param path string|obsidian.Path
---@param opts obsidian.note.LoadOpts|?
---
---@return obsidian.Note
Note.from_file_async = function(path, opts)
  local f = File.open(Path.new(path):resolve { strict = true })
  local ok, res = pcall(Note.from_lines, f:lines(false), path, opts)
  f:close()
  if ok then
    return res
  else
    error(res)
  end
end

--- Like `.from_file_async()` but also returns the contents of the file as a list of lines.
---
---@param path string|obsidian.Path
---@param opts obsidian.note.LoadOpts|?
---
---@return obsidian.Note,string[]
Note.from_file_with_contents_async = function(path, opts)
  opts = vim.tbl_extend("force", opts or {}, { load_contents = true })
  local note = Note.from_file_async(path, opts)
  assert(note.contents ~= nil)
  return note, note.contents
end

--- Initialize a note from a buffer.
---
---@param bufnr integer|?
---@param opts obsidian.note.LoadOpts|?
---
---@return obsidian.Note
Note.from_buffer = function(bufnr, opts)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local note = Note.from_lines(iter(lines), path, opts)
  note.bufnr = bufnr
  return note
end

--- Get the display name for note.
---
---@return string
Note.display_name = function(self)
  if self.title then
    return self.title
  elseif #self.aliases > 0 then
    return self.aliases[#self.aliases]
  end
  return tostring(self.id)
end

--- Initialize a note from an iterator of lines.
---
---@param lines fun(): string|?
---@param path string|obsidian.Path
---@param opts obsidian.note.LoadOpts|?
---
---@return obsidian.Note
Note.from_lines = function(lines, path, opts)
  opts = opts or {}
  path = Path.new(path):resolve()

  local max_lines = opts.max_lines or DEFAULT_MAX_LINES

  local id = nil
  local title = nil
  local aliases = {}
  local tags = {}

  ---@type string[]|?
  local contents
  if opts.load_contents then
    contents = {}
  end

  ---@type table<string, obsidian.note.HeaderAnchor>|?
  local anchor_links
  ---@type obsidian.note.HeaderAnchor[]|?
  local anchor_stack
  if opts.collect_anchor_links then
    anchor_links = {}
    anchor_stack = {}
  end

  ---@type table<string, obsidian.note.Block>|?
  local blocks
  if opts.collect_blocks then
    blocks = {}
  end

  ---@param anchor_data obsidian.note.HeaderAnchor
  ---@return obsidian.note.HeaderAnchor|?
  local function get_parent_anchor(anchor_data)
    assert(anchor_links)
    assert(anchor_stack)
    for i = #anchor_stack, 1, -1 do
      local parent = anchor_stack[i]
      if parent.level < anchor_data.level then
        return parent
      end
    end
  end

  ---@param anchor string
  ---@param data obsidian.note.HeaderAnchor|?
  local function format_nested_anchor(anchor, data)
    local out = anchor
    if not data then
      return out
    end

    local parent = data.parent
    while parent ~= nil do
      out = parent.anchor .. out
      data = get_parent_anchor(parent)
      if data then
        parent = data.parent
      else
        parent = nil
      end
    end

    return out
  end

  -- Iterate over lines in the file, collecting frontmatter and parsing the title.
  local frontmatter_lines = {}
  local has_frontmatter, in_frontmatter, at_boundary = false, false, false -- luacheck: ignore (false positive)
  local frontmatter_end_line = nil
  local in_code_block = false
  for line_idx, line in enumerate(lines) do
    line = util.rstrip_whitespace(line)

    if line_idx == 1 and Note._is_frontmatter_boundary(line) then
      has_frontmatter = true
      at_boundary = true
      in_frontmatter = true
    elseif in_frontmatter and Note._is_frontmatter_boundary(line) then
      at_boundary = true
      in_frontmatter = false
      frontmatter_end_line = line_idx
    else
      at_boundary = false
    end

    if string.match(line, CODE_BLOCK_PATTERN) then
      in_code_block = not in_code_block
    end

    if in_frontmatter and not at_boundary then
      table.insert(frontmatter_lines, line)
    elseif not in_frontmatter and not at_boundary and not in_code_block then
      -- Check for title/header and collect anchor link.
      local header_match = util.parse_header(line)
      if header_match then
        if not title and header_match.level == 1 then
          title = header_match.header
        end

        -- Collect anchor link.
        if opts.collect_anchor_links then
          assert(anchor_links)
          assert(anchor_stack)
          -- We collect up to two anchor for each header. One standalone, e.g. '#header1', and
          -- one with the parents, e.g. '#header1#header2'.
          -- This is our standalone one:
          ---@type obsidian.note.HeaderAnchor
          local data = {
            anchor = header_match.anchor,
            line = line_idx,
            header = header_match.header,
            level = header_match.level,
          }
          data.parent = get_parent_anchor(data)

          anchor_links[header_match.anchor] = data
          table.insert(anchor_stack, data)

          -- Now if there's a parent we collect the nested version. All of the data will be the same
          -- except the anchor key.
          if data.parent ~= nil then
            local nested_anchor = format_nested_anchor(header_match.anchor, data)
            anchor_links[nested_anchor] = vim.tbl_extend("force", data, { anchor = nested_anchor })
          end
        end
      end

      -- Check for block.
      if opts.collect_blocks then
        local block = util.parse_block(line)
        if block then
          blocks[block] = { id = block, line = line_idx, block = line }
        end
      end
    end

    -- Collect contents.
    if contents ~= nil then
      table.insert(contents, line)
    end

    -- Check if we can stop reading lines now.
    if
      line_idx > max_lines
      or (title and not opts.load_contents and not opts.collect_anchor_links and not opts.collect_blocks)
    then
      break
    end
  end

  if title ~= nil then
    -- Remove references and links from title
    title = search.replace_refs(title)
  end

  -- Parse the frontmatter YAML.
  local metadata = nil
  if #frontmatter_lines > 0 then
    local frontmatter = table.concat(frontmatter_lines, "\n")
    local ok, data = pcall(yaml.loads, frontmatter)
    if type(data) ~= "table" then
      data = {}
    end
    if ok then
      ---@diagnostic disable-next-line: param-type-mismatch
      for k, v in pairs(data) do
        if k == "id" then
          if type(v) == "string" or type(v) == "number" then
            id = v
          else
            log.warn("Invalid 'id' in frontmatter for " .. tostring(path))
          end
        elseif k == "aliases" then
          if type(v) == "table" then
            for alias in iter(v) do
              if type(alias) == "string" then
                table.insert(aliases, alias)
              else
                log.warn(
                  "Invalid alias value found in frontmatter for "
                    .. path
                    .. ". Expected string, found "
                    .. type(alias)
                    .. "."
                )
              end
            end
          elseif type(v) == "string" then
            table.insert(aliases, v)
          else
            log.warn("Invalid 'aliases' in frontmatter for " .. tostring(path))
          end
        elseif k == "tags" then
          if type(v) == "table" then
            for tag in iter(v) do
              if type(tag) == "string" then
                table.insert(tags, tag)
              else
                log.warn(
                  "Invalid tag value found in frontmatter for "
                    .. tostring(path)
                    .. ". Expected string, found "
                    .. type(tag)
                    .. "."
                )
              end
            end
          elseif type(v) == "string" then
            tags = vim.split(v, " ")
          else
            log.warn("Invalid 'tags' in frontmatter for '%s'", path)
          end
        else
          if metadata == nil then
            metadata = {}
          end
          metadata[k] = v
        end
      end
    end
  end

  -- ID should default to the filename without the extension.
  if id == nil or id == path.name then
    id = path.stem
  end
  assert(id)

  local n = Note.new(id, aliases, tags, path)
  n.title = title
  n.metadata = metadata
  n.has_frontmatter = has_frontmatter
  n.frontmatter_end_line = frontmatter_end_line
  n.contents = contents
  n.anchor_links = anchor_links
  n.blocks = blocks
  return n
end

--- Check if a line matches a frontmatter boundary.
---
---@param line string
---
---@return boolean
---
---@private
Note._is_frontmatter_boundary = function(line)
  return line:match "^---+$" ~= nil
end

--- Get the frontmatter table to save.
---
---@return table
Note.frontmatter = function(self)
  local out = { id = self.id, aliases = self.aliases, tags = self.tags }
  if self.metadata ~= nil and not vim.tbl_isempty(self.metadata) then
    for k, v in pairs(self.metadata) do
      out[k] = v
    end
  end
  return out
end

--- Get frontmatter lines that can be written to a buffer.
---
---@param eol boolean|?
---@param frontmatter table|?
---
---@return string[]
Note.frontmatter_lines = function(self, eol, frontmatter)
  local new_lines = { "---" }

  local frontmatter_ = frontmatter and frontmatter or self:frontmatter()
  if vim.tbl_isempty(frontmatter_) then
    return {}
  end

  for line in
    iter(yaml.dumps_lines(frontmatter_, function(a, b)
      local a_idx = nil
      local b_idx = nil
      for i, k in ipairs { "id", "aliases", "tags" } do
        if a == k then
          a_idx = i
        end
        if b == k then
          b_idx = i
        end
      end
      if a_idx ~= nil and b_idx ~= nil then
        return a_idx < b_idx
      elseif a_idx ~= nil then
        return true
      elseif b_idx ~= nil then
        return false
      else
        return a < b
      end
    end))
  do
    table.insert(new_lines, line)
  end

  table.insert(new_lines, "---")
  if not self.has_frontmatter then
    -- Make sure there's an empty line between end of the frontmatter and the contents.
    table.insert(new_lines, "")
  end

  if eol then
    return vim.tbl_map(function(l)
      return l .. "\n"
    end, new_lines)
  else
    return new_lines
  end
end

--- Save the note to a file.
--- In general this only updates the frontmatter and header, leaving the rest of the contents unchanged
--- unless you use the `update_content()` callback.
---
---@param opts { path: string|obsidian.Path|?, insert_frontmatter: boolean|?, frontmatter: table|?, update_content: (fun(lines: string[]): string[])|? }|? Options.
---
--- Options:
---  - `path`: Specify a path to save to. Defaults to `self.path`.
---  - `insert_frontmatter`: Whether to insert/update frontmatter. Defaults to `true`.
---  - `frontmatter`: Override the frontmatter. Defaults to the result of `self:frontmatter()`.
---  - `update_content`: A function to update the contents of the note. This takes a list of lines
---    representing the text to be written excluding frontmatter, and returns the lines that will
---    actually be written (again excluding frontmatter).
Note.save = function(self, opts)
  opts = opts or {}

  if self.path == nil and opts.path == nil then
    error "a path is required"
  end

  local save_path = Path.new(assert(opts.path or self.path)):resolve()
  assert(save_path:parent()):mkdir { parents = true, exist_ok = true }

  -- Read contents from existing file or buffer, if there is one.
  -- TODO: check for open buffer?
  ---@type string[]
  local content = {}
  ---@type string[]
  local existing_frontmatter = {}
  if self.path ~= nil and self.path:is_file() then
    with(open(tostring(self.path)), function(reader)
      local in_frontmatter, at_boundary = false, false -- luacheck: ignore (false positive)
      for idx, line in enumerate(reader:lines()) do
        if idx == 1 and Note._is_frontmatter_boundary(line) then
          at_boundary = true
          in_frontmatter = true
        elseif in_frontmatter and Note._is_frontmatter_boundary(line) then
          at_boundary = true
          in_frontmatter = false
        else
          at_boundary = false
        end

        if not in_frontmatter and not at_boundary then
          table.insert(content, line)
        else
          table.insert(existing_frontmatter, line)
        end
      end
    end)
  elseif self.title ~= nil then
    -- Add a header.
    table.insert(content, "# " .. self.title)
  end

  -- Pass content through callback.
  if opts.update_content then
    content = opts.update_content(content)
  end

  ---@type string[]
  local new_lines
  if opts.insert_frontmatter ~= false then
    -- Replace frontmatter.
    new_lines = compat.flatten { self:frontmatter_lines(false, opts.frontmatter), content }
  else
    -- Use existing frontmatter.
    new_lines = compat.flatten { existing_frontmatter, content }
  end

  -- Write new lines.
  with(open(tostring(save_path), "w"), function(writer)
    for _, line in ipairs(new_lines) do
      writer:write(line .. "\n")
    end
  end)
end

--- Save frontmatter to the given buffer.
---
---@param opts { bufnr: integer|?, insert_frontmatter: boolean|?, frontmatter: table|? }|? Options.
---
---@return boolean updated True if the buffer lines were updated, false otherwise.
Note.save_to_buffer = function(self, opts)
  opts = opts or {}

  local bufnr = opts.bufnr
  if not bufnr then
    bufnr = self.bufnr or 0
  end

  local cur_buf_note = Note.from_buffer(bufnr)

  ---@type string[]
  local new_lines
  if opts.insert_frontmatter ~= false then
    new_lines = self:frontmatter_lines(nil, opts.frontmatter)
  else
    new_lines = {}
  end

  if util.buffer_is_empty(bufnr) and self.title ~= nil then
    table.insert(new_lines, "# " .. self.title)
  end

  ---@type string[]
  local cur_lines = {}
  if cur_buf_note.frontmatter_end_line ~= nil then
    cur_lines = vim.api.nvim_buf_get_lines(bufnr, 0, cur_buf_note.frontmatter_end_line, false)
  end

  if not vim.deep_equal(cur_lines, new_lines) then
    vim.api.nvim_buf_set_lines(
      bufnr,
      0,
      cur_buf_note.frontmatter_end_line and cur_buf_note.frontmatter_end_line or 0,
      false,
      new_lines
    )
    return true
  else
    return false
  end
end

--- Try to resolve an anchor link to a line number in the note's file.
---
---@param anchor_link string
---@return obsidian.note.HeaderAnchor|?
Note.resolve_anchor_link = function(self, anchor_link)
  anchor_link = util.standardize_anchor(anchor_link)

  if self.anchor_links ~= nil then
    return self.anchor_links[anchor_link]
  end

  assert(self.path, "'note.path' is not set")
  local n = Note.from_file(self.path, { collect_anchor_links = true })
  self.anchor_links = n.anchor_links
  return n:resolve_anchor_link(anchor_link)
end

--- Try to resolve a block identifier.
---
---@param block_id string
---
---@return obsidian.note.Block|?
Note.resolve_block = function(self, block_id)
  block_id = util.standardize_block(block_id)

  if self.blocks ~= nil then
    return self.blocks[block_id]
  end

  assert(self.path, "'note.path' is not set")
  local n = Note.from_file(self.path, { collect_blocks = true })
  return n:resolve_block(block_id)
end

--- Returns the content of the note file if exist and nil if it does not
---
---@return string[]|?
Note.read_note = function(self)
  if self:exists() then
    local contents = {}

    with(open(tostring(self.path), "r"), function(reader)
      local line = reader:read()
      while line ~= nil do
        line = reader:read()
        table.insert(contents, line)
      end
    end)
    return contents
  end
end

return Note
