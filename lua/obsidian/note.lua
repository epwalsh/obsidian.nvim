local Path = require "plenary.path"
local yaml = require "obsidian.yaml"
local util = require "obsidian.util"
local echo = require "obsidian.echo"

local SKIP_UPDATING_FRONTMATTER = { "README.md", "CONTRIBUTING.md", "CHANGELOG.md" }

---@class obsidian.Note
---@field id string
---@field aliases string[]
---@field tags string[]
---@field path Path|?
---@field metadata table|?
---@field has_frontmatter boolean|?
---@field frontmatter_end_line integer|?
local note = {}

---Create new note.
---
---@param id string
---@param aliases string[]
---@param tags string[]
---@param path string|Path|?
---@return obsidian.Note
note.new = function(id, aliases, tags, path)
  local self = setmetatable({}, { __index = note })
  self.id = id
  self.aliases = aliases and aliases or {}
  self.tags = tags and tags or {}
  self.path = path and Path:new(path) or nil
  self.metadata = nil
  self.has_frontmatter = nil
  self.frontmatter_end_line = nil
  return self
end

---Check if the note exists on the file system.
---
---@return boolean
note.exists = function(self)
  ---@diagnostic disable-next-line: return-type-mismatch
  return self.path ~= nil and self.path:is_file()
end

---Get the filename associated with the note.
---
---@return string|?
note.fname = function(self)
  if self.path == nil then
    return nil
  else
    return vim.fs.basename(tostring(self.path))
  end
end

note.should_save_frontmatter = function(self)
  local fname = self:fname()
  return (fname ~= nil and not util.contains(SKIP_UPDATING_FRONTMATTER, fname))
end

---Check if a note has a given alias.
---
---@param alias string
---@return boolean
note.has_alias = function(self, alias)
  return util.contains(self.aliases, alias)
end

---Check if a note has a given tag.
---
---@param tag string
---@return boolean
note.has_tag = function(self, tag)
  return util.contains(self.tags, tag)
end

---Add an alias to the note.
---
---@param alias string
note.add_alias = function(self, alias)
  if not self:has_alias(alias) then
    table.insert(self.aliases, alias)
  end
end

---Add a tag to the note.
---
---@param tag string
note.add_tag = function(self, tag)
  if not self:has_tag(tag) then
    table.insert(self.tags, tag)
  end
end

---Initialize a note from a file.
---
---@param path string|Path
---@param root string|Path|?
---@return obsidian.Note
note.from_file = function(path, root)
  if path == nil then
    echo.fail "note path cannot be nil"
    error()
  end
  local f = io.open(vim.fs.normalize(tostring(path)))
  if f == nil then
    echo.fail("failed to read file at " .. tostring(path))
    error()
  end
  local n = note.from_lines(function()
    return f:lines()
  end, path, root)
  f:close()
  return n
end

---Initialize a note from a buffer.
---
---@param bufnr integer|?
---@param root string|Path|?
---@return obsidian.Note
note.from_buffer = function(bufnr, root)
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

  return note.from_lines(lines_iter, path, root)
end

---Get the display name for note.
---
---@return string
note.display_name = function(self)
  if #self.aliases > 0 then
    return self.aliases[#self.aliases]
  end
  return self.id
end

---Initialize a note from an iterator of lines.
---
---@param lines function
---@param path string|Path
---@param root string|Path|?
---@return obsidian.Note
note.from_lines = function(lines, path, root)
  local cwd = tostring(root and root or "./")
  local relative_path = tostring(Path:new(path):make_relative(cwd))

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
      if note._is_frontmatter_boundary(line) then
        has_frontmatter = true
        in_frontmatter = true
      else
        local maybe_title = note._parse_header(line)
        if maybe_title then
          title = maybe_title
          break
        end
      end
    elseif has_frontmatter and in_frontmatter then
      if note._is_frontmatter_boundary(line) then
        in_frontmatter = false
        frontmatter_end_line = line_idx
      else
        table.insert(frontmatter_lines, line)
      end
    else
      local maybe_title = note._parse_header(line)
      if maybe_title then
        title = maybe_title
        break
      end
    end
  end

  if title ~= nil then
    -- Remove references and links from title
    title = util.replace_refs(title)
  end

  -- Parse the frontmatter YAML.
  local metadata = nil
  if #frontmatter_lines > 0 then
    local frontmatter = table.concat(frontmatter_lines, "\n")
    local ok, data = pcall(yaml.loads, frontmatter)
    if ok then
      for k, v in pairs(data) do
        if k == "id" then
          id = v
        elseif k == "aliases" then
          aliases = v
        elseif k == "tags" then
          tags = v
        else
          if metadata == nil then
            metadata = {}
          end
          metadata[k] = v
        end
      end
    end
  end

  -- Use title as an alias.
  if title ~= nil and not util.contains(aliases, title) then
    table.insert(aliases, title)
  end

  -- Fall back to using the relative path as the ID.
  if id == nil then
    id = relative_path
  end

  local n = note.new(id, aliases, tags, path)
  n.metadata = metadata
  n.has_frontmatter = has_frontmatter
  n.frontmatter_end_line = frontmatter_end_line
  return n
end

---Check if a line matches a frontmatter boundary.
---
---@param line string
---@return boolean
note._is_frontmatter_boundary = function(line)
  return line:match "^---+$" ~= nil
end

---Try parsing a header from a line.
---
---@param line string
---@return string|?
note._parse_header = function(line)
  return line:match "^#+ (.+)$"
end

---Get frontmatter lines that can be written to a buffer.
---
---@param eol boolean|?
---@return string[]
note.frontmatter_lines = function(self, eol)
  local new_lines = { "---" }

  for _, line in ipairs(yaml.dumps_lines { id = self.id }) do
    table.insert(new_lines, line)
  end

  for _, line in ipairs(yaml.dumps_lines { aliases = self.aliases }) do
    table.insert(new_lines, line)
  end

  for _, line in ipairs(yaml.dumps_lines { tags = self.tags }) do
    table.insert(new_lines, line)
  end

  if self.metadata ~= nil and util.table_length(self.metadata) > 0 then
    for _, line in ipairs(yaml.dumps_lines(self.metadata)) do
      table.insert(new_lines, line)
    end
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

---Save note to file.
---
---@param path string|Path|?
note.save = function(self, path)
  if self.path == nil then
    echo.fail "note path cannot be nil"
    error()
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
      table.insert(lines, line .. "\n")
      if idx == 1 then
        if note._is_frontmatter_boundary(line) then
          has_frontmatter = true
          in_frontmatter = true
        end
      elseif has_frontmatter and in_frontmatter then
        if note._is_frontmatter_boundary(line) then
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
  local new_lines = self:frontmatter_lines(true)

  -- Add remaining original lines.
  for i = end_idx + 1, #lines do
    table.insert(new_lines, lines[i])
  end

  --Write new lines.
  local save_path = vim.fs.normalize(tostring(path and path or self.path))
  assert(save_path ~= nil)
  local save_f = io.open(save_path, "w")
  if save_f == nil then
    echo.fail("failed to write file at " .. save_path)
    error()
  end
  for _, line in pairs(new_lines) do
    save_f:write(line)
  end
  save_f:close()

  return lines
end

return note
