local log = require "obsidian.log"
local util = require "obsidian.util"
local search = require "obsidian.search"
local LocationList = require "obsidian.location_list"

---@param client obsidian.Client
---@param tags string[]
local function gather_tag_location_list(client, tags)
  -- Gather tag locations.
  local tag_locations = {}
  local tag_locs = client:find_tags(tags, { sort = true })
  for _, tag_loc in ipairs(tag_locs) do
    for _, tag in ipairs(tags) do
      if tag_loc.tag == tag then
        tag_locations[#tag_locations + 1] = tag_loc
      end
    end
  end

  if vim.tbl_isempty(tag_locations) then
    log.warn "Tags not found"
    return
  end

  -- Group tag locations by path, keeping order.
  -- Note: tag locations will be in order by path+line in the flat.
  ---@type { [1]: string, [2]: obsidian.Note, [3]: obsidian.TagLocation[]}[]
  local matches_by_path = {}
  for _, tag_loc in ipairs(tag_locations) do
    local path = tag_loc.path
    local matches = matches_by_path[#matches_by_path]
    if not matches or matches[1] ~= path then
      matches = { path, tag_loc.note, {} }
      matches_by_path[#matches_by_path + 1] = matches
    end

    matches[3][#matches[3] + 1] = tag_loc
  end

  local loclist = LocationList.new(client, assert(vim.fn.bufnr()), vim.fn.winnr(), "ObsidianTags", client.opts.tags)

  -- Collect lines, highlights, and folds for location list window.
  local view_lines = {}
  local highlights = {}
  local folds = {}

  for _, path_matches in ipairs(matches_by_path) do
    ---@type obsidian.Note
    local note
    ---@type obsidian.TagLocation[]
    local matches
    _, note, matches = unpack(path_matches)

    local display_path = assert(client:vault_relative_path(note.path))

    -- Header for note.
    view_lines[#view_lines + 1] = (" %s"):format(note:display_name())
    highlights[#highlights + 1] = { group = "CursorLineNr", line = #view_lines - 1, col_start = 0, col_end = 1 }
    highlights[#highlights + 1] = { group = "Directory", line = #view_lines - 1, col_start = 2, col_end = -1 }

    -- Lines for each tag match within note.
    for _, line_match in ipairs(matches) do
      -- local text, ref_indices, ref_strs = search.find_and_replace_refs(line_match.text)
      local text_start = 4 + display_path:len() + tostring(line_match.line):len()
      view_lines[#view_lines + 1] = ("  %s:%s:%s"):format(display_path, line_match.line, line_match.text)

      -- Add highlight for tag match in the text.
      if line_match.tag_start and line_match.tag_end then
        table.insert(highlights, {
          group = "Search",
          line = #view_lines - 1,
          col_start = text_start + line_match.tag_start - 1,
          col_end = text_start + line_match.tag_end,
        })
      end

      -- Add highlight for path and line number
      highlights[#highlights + 1] = {
        group = "Comment",
        line = #view_lines - 1,
        col_start = 2,
        col_end = text_start,
      }
    end

    folds[#folds + 1] = { range = { #view_lines - #matches, #view_lines } }
    view_lines[#view_lines + 1] = ""
  end

  -- Remove last blank line.
  view_lines[#view_lines] = nil

  loclist:render(view_lines, folds, highlights)

  log.info(
    "Showing tag locations for '%s'.\n\n"
      .. "TIPS:\n\n"
      .. "- Hit ENTER on a match to go to the tag location\n"
      .. "- Hit ENTER on a group header to toggle the fold, or use normal fold mappings",
    table.concat(tags, "', '")
  )
end

---@param client obsidian.Client
return function(client, data)
  local tags = data.fargs

  if vim.tbl_isempty(tags) then
    -- Check for visual selection.
    local _, csrow, cscol, _ = unpack(assert(vim.fn.getpos "'<"))
    local _, cerow, cecol, _ = unpack(assert(vim.fn.getpos "'>"))
    if data.line1 == csrow and data.line2 == cerow then
      local lines = vim.fn.getline(csrow, cerow)
      if #lines ~= 1 then
        log.err "Only in-line visual selections allowed"
        return
      end

      local line = assert(lines[1])
      local tag = string.sub(line, cscol, cecol)

      if not string.match(tag, "^#?" .. search.Patterns.TagCharsRequired .. "$") then
        log.err("Visual selection '%s' is not a valid tag", tag)
        return
      end

      if vim.startswith(tag, "#") then
        tag = string.sub(tag, 2)
      end

      tags = { tag }
    else
      -- Otherwise check for a tag under the cursor.
      local tag = util.cursor_tag()
      if tag then
        tags = { tag }
      end
    end
  end

  if not vim.tbl_isempty(tags) then
    return gather_tag_location_list(client, util.tbl_unique(tags))
  else
    -- Open finder with tags.
    client:_run_with_finder_backend({
      ["telescope.nvim"] = function()
        -- try with telescope.nvim
        local has_telescope, _ = pcall(require, "telescope")
        if not has_telescope then
          return false
        end

        local pickers = require "telescope.pickers"
        local finders = require "telescope.finders"
        local conf = require("telescope.config").values

        local opts = {
          attach_mappings = function(_, map)
            -- NOTE: in newer versions of Telescope we can make a single call to `map()` with
            -- `mode = { "i", "n" }`, but older versions expect mode to be string, not a table.
            for _, mode in ipairs { "i", "n" } do
              map(mode, "<CR>", function(prompt_bufnr)
                local tag = require("telescope.actions.state").get_selected_entry()[1]
                require("telescope.actions").close(prompt_bufnr)
                gather_tag_location_list(client, { tag })
              end)
            end
            return true
          end,
        }

        client:list_tags_async(function(all_tags)
          vim.schedule(function()
            pickers
              .new(opts, {
                prompt_title = "Tags",
                finder = finders.new_table {
                  results = all_tags,
                },
                sorter = conf.generic_sorter(opts),
              })
              :find()
          end)
        end)

        return true
      end,
    }, function()
      log.warn "Finder not available for tags, please provide a tag argument to the command"
    end)
  end
end
