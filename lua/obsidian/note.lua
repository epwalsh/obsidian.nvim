local Path = require "plenary.path"
local yaml = require "obsidian.yaml"
local util = require "obsidian.util"
local echo = require "obsidian.echo"
local with = require("plenary.context_manager").with
local open = require("plenary.context_manager").open

local SKIP_UPDATING_FRONTMATTER = { "README.md", "CONTRIBUTING.md", "CHANGELOG.md" }

---@class obsidian.Note
---@field id string|integer
---@field aliases string[]
---@field tags string[]
---@field path Path|?
---@field metadata table|?
---@field has_frontmatter boolean|?
---@field frontmatter_end_line integer|?
local Note = {}

---Create new note.
---
---@param id string|number
---@param aliases string[]
---@param tags string[]
---@param path string|Path|?
---@return obsidian.Note
Note.new = function(id, aliases, tags, path)
  local self = setmetatable({}, { __index = Note })
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
Note.exists = function(self)
  ---@diagnostic disable-next-line: return-type-mismatch
  return self.path ~= nil and self.path:is_file()
end

---Get the filename associated with the note.
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
  return (fname ~= nil and not util.contains(SKIP_UPDATING_FRONTMATTER, fname))
end

---Check if a note has a given alias.
---
---@param alias string
---@return boolean
Note.has_alias = function(self, alias)
  return util.contains(self.aliases, alias)
end

---Check if a note has a given tag.
---
---@param tag string
---@return boolean
Note.has_tag = function(self, tag)
  return util.contains(self.tags, tag)
end

---Add an alias to the note.
---
---@param alias string
Note.add_alias = function(self, alias)
  if not self:has_alias(alias) then
    table.insert(self.aliases, alias)
  end
end

---Add a tag to the note.
---
---@param tag string
Note.add_tag = function(self, tag)
  if not self:has_tag(tag) then
    table.insert(self.tags, tag)
  end
end

---Initialize a note from a file.
---
---@param path string|Path
---@param root string|Path|?
---@return obsidian.Note
Note.from_file = function(path, root)
  if path == nil then
    echo.fail "note path cannot be nil"
    error()
  end
  local n
  with(open(vim.fs.normalize(tostring(path))), function(reader)
    n = Note.from_lines(function()
      return reader:lines()
    end, path, root)
  end)
  return n
end

---An async version of `.from_file()`.
---
---@param path string|Path
---@param root string|Path|?
---@return obsidian.Note
Note.from_file_async = function(path, root)
  local File = require("obsidian.async").File
  if path == nil then
    echo.fail "note path cannot be nil"
    error()
  end
  local f = File.open(vim.fs.normalize(tostring(path)))
  local n = Note.from_lines(function()
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

---Get the display name for note.
---
---@return string
Note.display_name = function(self)
  if #self.aliases > 0 then
    return self.aliases[#self.aliases]
  end
  return tostring(self.id)
end

---Initialize a note from an iterator of lines.
---
---@param lines function
---@param path string|Path
---@param root string|Path|?
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
    title = util.replace_refs(title)
  end

  -- Parse the frontmatter YAML.
  local metadata = nil
  if #frontmatter_lines > 0 then
    local frontmatter = table.concat(frontmatter_lines, "\n")
    local ok, data = pcall(yaml.loads, frontmatter)
    if type(data) == "string" then
      data = {}
    end
    if ok then
      ---@diagnostic disable-next-line: param-type-mismatch
      for k, v in pairs(data) do
        if k == "id" then
          if type(v) == "string" or type(v) == "number" then
            id = v
          else
            echo.warn("Invalid 'id' in frontmatter for " .. tostring(path))
          end
        elseif k == "aliases" then
          if type(v) == "table" then
            for _, alias in ipairs(v) do
              if type(alias) == "string" then
                table.insert(aliases, alias)
              else
                echo.warn(
                  "Invalid alias value found in frontmatter for "
                    .. path
                    .. ". Expected string, found "
                    .. type(alias)
                    .. "."
                )
              end
            end
          else
            echo.warn("Invalid 'aliases' in frontmatter for " .. tostring(path))
          end
        elseif k == "tags" then
          if type(v) == "table" then
            for _, tag in ipairs(v) do
              if type(tag) == "string" then
                table.insert(tags, tag)
              else
                echo.warn(
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
            echo.warn("Invalid 'tags' in frontmatter for " .. tostring(path))
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

  -- Use title as an alias.
  if title ~= nil and not util.contains(aliases, title) then
    table.insert(aliases, title)
  end

  -- The ID should match the filename with or without the extension.
  local relative_path = tostring(Path:new(tostring(path)):make_relative(cwd))
  local relative_path_no_ext = vim.fn.fnamemodify(relative_path, ":r")
  local fname = vim.fs.basename(relative_path)
  local fname_no_ext = vim.fn.fnamemodify(fname, ":r")
  if id ~= relative_path and id ~= relative_path_no_ext and id ~= fname and id ~= fname_no_ext then
    id = fname_no_ext
  end

  local n = Note.new(id, aliases, tags, path)
  n.metadata = metadata
  n.has_frontmatter = has_frontmatter
  n.frontmatter_end_line = frontmatter_end_line
  return n
end

---Check if a line matches a frontmatter boundary.
---
---@param line string
---@return boolean
Note._is_frontmatter_boundary = function(line)
  return line:match "^---+$" ~= nil
end

---Try parsing a header from a line.
---
---@param line string
---@return string|?
Note._parse_header = function(line)
  return line:match "^#+ (.+)$"
end

---Get the frontmatter table to save.
---@return table
Note.frontmatter = function(self)
  local out = { id = self.id, aliases = self.aliases, tags = self.tags }
  if self.metadata ~= nil and util.table_length(self.metadata) > 0 then
    for k, v in pairs(self.metadata) do
      out[k] = v
    end
  end
  return out
end

---Get frontmatter lines that can be written to a buffer.
---
---@param eol boolean|?
---@param frontmatter table|?
---@return string[]
Note.frontmatter_lines = function(self, eol, frontmatter)
  local new_lines = { "---" }

  local frontmatter_ = frontmatter and frontmatter or self:frontmatter()
  for _, line in
    ipairs(yaml.dumps_lines(frontmatter_, function(a, b)
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

---Save note to file.
---
---@param path string|Path|?
---@param insert_frontmatter boolean|?
---@param frontmatter table|?
Note.save = function(self, path, insert_frontmatter, frontmatter)
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

return Note
