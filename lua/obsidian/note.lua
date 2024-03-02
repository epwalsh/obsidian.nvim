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

local SKIP_UPDATING_FRONTMATTER = { "README.md", "CONTRIBUTING.md", "CHANGELOG.md" }

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
local Note = abc.new_class {
  __tostring = function(self)
    return string.format("Note('%s')", self.id)
  end,
}

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
---@param opts { label: string|? }|?
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

  if #self.aliases > 0 then
    info[#info + 1] = ("**aliases:** '%s'"):format(table.concat(self.aliases, "', '"))
  end

  if #self.tags > 0 then
    info[#info + 1] = ("**tags:** `#%s`"):format(table.concat(self.tags, "`, `#"))
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

--- Initialize a note from a file.
---
---@param path string|obsidian.Path
---
---@return obsidian.Note
Note.from_file = function(path)
  if path == nil then
    error "note path cannot be nil"
  end
  local n
  with(open(tostring(Path.new(path):resolve { strict = true })), function(reader)
    n = Note.from_lines(reader:lines(), path)
  end)
  return n
end

--- An async version of `.from_file()`, i.e. it needs to be called in an async context.
---
---@param path string|obsidian.Path
---
---@return obsidian.Note
Note.from_file_async = function(path)
  local f = File.open(Path.new(path):resolve { strict = true })
  local ok, res = pcall(Note.from_lines, f:lines(false), path)
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
---
---@return obsidian.Note,string[]
Note.from_file_with_contents_async = function(path)
  path = Path.new(path):resolve { strict = true }
  local f = File.open(path)
  local content = {}
  for line in f:lines(false) do
    table.insert(content, line)
  end
  f:close()
  return Note.from_lines(iter(content), path), content
end

--- Initialize a note from a buffer.
---
---@param bufnr integer|?
---
---@return obsidian.Note
Note.from_buffer = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return Note.from_lines(iter(lines), path)
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
---
---@return obsidian.Note
Note.from_lines = function(lines, path)
  path = Path.new(path):resolve()

  local id = nil
  local title = nil
  local aliases = {}
  local tags = {}

  -- Iterate over lines in the file, collecting frontmatter and parsing the title.
  local frontmatter_lines = {}
  local has_frontmatter, in_frontmatter = false, false
  local frontmatter_end_line = nil
  local line_idx = 0
  for line in lines do
    line_idx = line_idx + 1
    if line_idx == 1 then
      if Note._is_frontmatter_boundary(line) then
        has_frontmatter = true
        in_frontmatter = true
      else
        local maybe_title = Note._parse_header(line)
        if maybe_title then
          title = maybe_title
          break
        end
      end
    elseif has_frontmatter and in_frontmatter then
      if Note._is_frontmatter_boundary(line) then
        in_frontmatter = false
        frontmatter_end_line = line_idx
      else
        table.insert(frontmatter_lines, line)
      end
    else
      local maybe_title = Note._parse_header(line)
      if maybe_title then
        title = maybe_title
        break
      end
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

--- Try parsing a header from a line.
---
---@param line string
---
---@return string|?
Note._parse_header = function(line)
  local header = line:match "^#+ (.+)$"
  if header then
    return util.strip_whitespace(header)
  else
    return nil
  end
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

  -- Read contents from existing file, if there is one, skipping frontmatter.
  -- TODO: check for open buffer?
  ---@type string[]
  local content = {}
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
    new_lines = vim.tbl_flatten { self:frontmatter_lines(false, opts.frontmatter), content }
  else
    new_lines = content
  end

  local save_path = Path.new(assert(opts.path or self.path)):resolve()
  assert(save_path:parent()):mkdir { parents = true, exist_ok = true }

  -- Write new lines.
  with(open(tostring(save_path), "w"), function(writer)
    for _, line in ipairs(new_lines) do
      writer:write(line .. "\n")
    end
  end)
end

--- Save frontmatter to the given buffer.
---
---@param bufnr integer|?
---@param frontmatter table|?
---
---@return boolean updated True if the buffer lines were updated, false otherwise.
Note.save_to_buffer = function(self, bufnr, frontmatter)
  bufnr = bufnr and bufnr or 0

  local cur_buf_note = Note.from_buffer(bufnr)
  local new_lines = self:frontmatter_lines(nil, frontmatter)
  local cur_lines
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
---@return integer|? line_number
Note.resolve_anchor_link = function(self, anchor_link)
  assert(self.path)
  ---@type integer
  local lnum
  with(open(tostring(self.path)), function(reader)
    for i, line in enumerate(reader:lines()) do
      if util.is_header(line) and util.header_to_anchor(line) == anchor_link then
        lnum = i
        break
      end
    end
  end)
  return lnum
end

return Note
