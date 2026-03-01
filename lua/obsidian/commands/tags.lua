local log = require "obsidian.log"
local util = require "obsidian.util"
local api = require "obsidian.api"
local search = require "obsidian.search"

---@param tag string
---@return string
local function normalize(tag)
  return tag:lower():gsub("^#", ""):gsub("^%+", ""):gsub("%s+", "")
end

---@param args any
---@return string[] tags, boolean and_mode, boolean hash_search
local function parse_args(args)
  local tags = {}
  local and_mode = false
  local hash_search = false

  for _, a in pairs(args or {}) do
    if type(a) == "string" and a ~= "" then
      if vim.startswith(a, "+") then
        and_mode = true
      end
      if vim.startswith(a, "#") then
        hash_search = true
      end
      tags[#tags + 1] = normalize(a)
    end
  end

  local seen = {}
  local unique = {}
  for _, t in ipairs(tags) do
    if not seen[t] then
      seen[t] = true
      unique[#unique + 1] = t
    end
  end

  return unique, and_mode, hash_search
end

---@param tag_locations obsidian.TagLocation[]
local function build_index(tag_locations)
  local notes = {}

  for _, loc in ipairs(tag_locations) do
    local key = tostring(loc.path)
    if not notes[key] then
      notes[key] = {
        note = loc.note,
        tags = {},
        locs = {},
      }
    end

    local t = normalize(loc.tag)
    notes[key].tags[t] = true
    notes[key].locs[#notes[key].locs + 1] = loc
  end

  return notes
end

---@param path string
---@return string[] lines
local function read_file_lines(path)
  local f = io.open(path, "r")
  if not f then
    return {}
  end
  local lines = {}
  for line in f:lines() do
    lines[#lines + 1] = line
  end
  f:close()
  return lines
end

local function open_picker(tag_locations, args)
  local query, and_mode, hash_search = parse_args(args)
  local notes = build_index(tag_locations)

  ---@type obsidian.PickerEntry[]
  local entries = {}

  for _, data in pairs(notes) do
    local match

    if and_mode then
      match = true
      for _, q in ipairs(query) do
        if not data.tags[q] then
          match = false
          break
        end
      end

      if match then
        local display = string.format(
          "%s [AND: %s]",
          data.note:display_name(),
          table.concat(query, ", ")
        )
        entries[#entries + 1] = {
          value = { path = data.note.path },
          display = display,
          ordinal = display,
          filename = tostring(data.note.path),
        }
      end

    else
      if hash_search then
        -- read file from disk
        local lines = read_file_lines(tostring(data.note.path))

        -- find YAML end
        local yaml_end = 0
        if lines[1] == "---" then
          for i = 2, #lines do
            if lines[i] == "---" then
              yaml_end = i
              break
            end
          end
        end

        for _, loc in ipairs(data.locs) do
          if loc.line > yaml_end then
            local t = normalize(loc.tag)
            for _, q in ipairs(query) do
              if t == q then
                local display = string.format(
                  "%s [%d] %s",
                  loc.note:display_name(),
                  loc.line,
                  loc.text
                )
                entries[#entries + 1] = {
                  value = {
                    path = loc.path,
                    line = loc.line,
                    col = loc.tag_start,
                  },
                  display = display,
                  ordinal = display,
                  filename = tostring(loc.path),
                  lnum = loc.line,
                  col = loc.tag_start,
                }
                break
              end
            end
          end
        end
      else
        local matched_tags = {}
        for _, q in ipairs(query) do
          if data.tags[q] then
            matched_tags[#matched_tags + 1] = q
          end
        end
        if #matched_tags > 0 then
          local display = string.format(
            "%s [OR: %s]",
            data.note:display_name(),
            table.concat(matched_tags, ", ")
          )
          entries[#entries + 1] = {
            value = { path = data.note.path },
            display = display,
            ordinal = display,
            filename = tostring(data.note.path),
          }
        end
      end
    end
  end

  if vim.tbl_isempty(entries) then
    log.warn "Tags not found"
    return
  end

  vim.schedule(function()
    Obsidian.picker.pick(entries, {
      prompt_title =
        (and_mode and "AND: " or "OR: ")
        .. table.concat(query, ", "),
    })
  end)
end

---@param data obsidian.CommandArgs
return function(data)
  local args = data.fargs or {}
  local dir = api.resolve_workspace_dir()

  if vim.tbl_isempty(args) then
    local tag = api.cursor_tag()
    if tag then
      args = { tag }
    end
  end

  if vim.tbl_isempty(args) then
    log.warn "No tag provided"
    return
  end

  search.find_tags_async("", function(tag_locations)
    open_picker(tag_locations, args)
  end, { dir = dir })
end




