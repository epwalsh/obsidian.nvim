local Path = require "plenary.path"
local abc = require "obsidian.abc"
local with = require("plenary.context_manager").with
local open = require("plenary.context_manager").open
local yaml = require "obsidian.yaml"
local log = require "obsidian.log"
local util = require "obsidian.util"
local search = require "obsidian.search"
local iter = require("obsidian.itertools").iter

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
---@field path Path|?
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
---@param path string|Path|?
---
---@return obsidian.Note
Note.new = function(id, aliases, tags, path)
  local self = Note.init()
  self.id = id
  self.aliases = aliases and aliases or {}
  self.tags = tags and tags or {}
  self.path = path and Path:new(path) or nil
  self.metadata = nil
  self.has_frontmatter = nil
  self.frontmatter_end_line = nil
  return self
end

--- Get markdown display info about the note.
---@return string
Note.display_info = function(self)
  ---@type string[]
  local info = {}

  if self.path ~= nil then
    info[#info + 1] = ("**path:** %s"):format(self.path)
  end

  if #self.aliases > 0 then
    info[#info + 1] = ("**aliases:** '%s'"):format(table.concat(self.aliases, "', '"))
  end

  if #self.tags > 0 then
    info[#info + 1] = ("**tags:** '%s'"):format(table.concat(self.tags, "', '"))
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
Note.add_alias = function(self, alias)
  if not self:has_alias(alias) then
    table.insert(self.aliases, alias)
  end
end

--- Add a tag to the note.
---
---@param tag string
Note.add_tag = function(self, tag)
  if not self:has_tag(tag) then
    table.insert(self.tags, tag)
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
---@param path string|Path
---@param root string|Path|?
---
---@return obsidian.Note
Note.from_file = function(path, root)
  if path == nil then
    error "note path cannot be nil"
  end
  local n
  with(open(vim.fs.normalize(tostring(path))), function(reader)
    n = Note.from_lines(function()
      return reader:lines()
    end, path, root)
  end)
  return n
end

--- An async version of `.from_file()`.
---
---@param path string|Path
---@param root string|Path|?
---
---@return obsidian.Note
Note.from_file_async = function(path, root)
  local File = require("obsidian.async").File
  if path == nil then
    error "note path cannot be nil"
  end
  local f = File.open(vim.fs.normalize(tostring(path)))
  local ok, res = pcall(Note.from_lines, function()
    return f:lines(false)
  end, path, root)
  f:close()
  if ok then
    return res
  else
    error(res)
  end
end

--- Initialize a note from a buffer.
---
---@param bufnr integer|?
---@param root string|Path|?
---
---@return obsidian.Note
Note.from_buffer = function(bufnr, root)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local lines_iter = function()
    local i = 0
    local n = #lines
    return function()
      i = i + 1
      if i <= n then
        return lines[i]
      else
        return nil
      end
    end
  end

  return Note.from_lines(lines_iter, path, root)
end

--- Get the display name for note.
---
---@return string
Note.display_name = function(self)
  if #self.aliases > 0 then
    return self.aliases[#self.aliases]
  end
  return tostring(self.id)
end

--- Initialize a note from an iterator of lines.
---
---@param lines function
---@param path string|Path
---@param root string|Path|?
---
---@return obsidian.Note
Note.from_lines = function(lines, path, root)
  local cwd = tostring(root and root or "./")

  local id = nil
  local title = nil
  local aliases = {}
  local tags = {}

  -- Iterate over lines in the file, collecting frontmatter and parsing the title.
  local frontmatter_lines = {}
  local has_frontmatter, in_frontmatter = false, false
  local frontmatter_end_line = nil
  local line_idx = 0
  for line in lines() do
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
            log.warn("Invalid 'tags' in frontmatter for " .. tostring(path))
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

  -- The ID should match the filename with or without the extension.
  local relative_path = tostring(Path:new(tostring(path)):make_relative(cwd))
  local relative_path_no_ext = relative_path
  if vim.endswith(relative_path_no_ext, ".md") then
    -- NOTE: alternatively we could use `vim.fn.fnamemodify`, but that will give us luv errors
    -- when called from an async context on certain operating systems.
    -- relative_path_no_ext = vim.fn.fnamemodify(relative_path, ":r")
    relative_path_no_ext = relative_path_no_ext:sub(1, -4)
  end
  local fname = assert(vim.fs.basename(relative_path))
  local fname_no_ext = fname
  if vim.endswith(fname_no_ext, ".md") then
    fname_no_ext = fname_no_ext:sub(1, -4)
  end
  if id ~= relative_path and id ~= relative_path_no_ext and id ~= fname and id ~= fname_no_ext then
    id = fname_no_ext
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

--- Save note to file. This only updates the frontmatter and header, leaving the rest of the contents unchanged.
---
---@param path string|Path|?
---@param insert_frontmatter boolean|?
---@param frontmatter table|?
Note.save = function(self, path, insert_frontmatter, frontmatter)
  if self.path == nil then
    error "note path cannot be nil"
  end

  local lines = {}
  local has_frontmatter, in_frontmatter = false, false
  local end_idx = 0

  -- Read lines from existing file, if there is one.
  -- TODO: check for open buffer.
  local self_f = io.open(tostring(self.path))
  if self_f ~= nil then
    local contents = self_f:read "*a"
    for idx, line in ipairs(vim.split(contents, "\n")) do
      lines[#lines + 1] = line .. "\n"

      if idx == 1 then
        if Note._is_frontmatter_boundary(line) then
          has_frontmatter = true
          in_frontmatter = true
        end
      elseif has_frontmatter and in_frontmatter then
        if Note._is_frontmatter_boundary(line) then
          end_idx = idx
          in_frontmatter = false
        end
      end
    end

    self_f:close()
  elseif #self.aliases > 0 then
    -- Add a header.
    table.insert(lines, "# " .. self.aliases[1])
  end

  -- Replace frontmatter.
  local new_lines = {}
  if insert_frontmatter ~= false then
    new_lines = self:frontmatter_lines(true, frontmatter)
  end

  -- Add remaining original lines.
  for i = end_idx + 1, #lines do
    table.insert(new_lines, lines[i])
  end

  --Write new lines.
  local save_path = vim.fs.normalize(tostring(path and path or self.path))
  assert(save_path ~= nil)
  util.parent_directory(save_path):mkdir { parents = true, exists_ok = true }
  local save_f = io.open(save_path, "w")
  if save_f == nil then
    error(string.format("failed to write file at " .. save_path))
  end
  for _, line in pairs(new_lines) do
    save_f:write(line)
  end
  save_f:close()

  return lines
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

  vim.api.nvim_buf_set_lines(
    bufnr,
    0,
    cur_buf_note.frontmatter_end_line and cur_buf_note.frontmatter_end_line or 0,
    false,
    new_lines
  )

  return not vim.deep_equal(cur_lines, new_lines)
end

return Note
