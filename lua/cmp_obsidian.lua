local abc = require "obsidian.abc"
local completion = require "obsidian.completion.refs"
local obsidian = require "obsidian"
local util = require "obsidian.util"
local iter = require("obsidian.itertools").iter
local LinkStyle = require("obsidian.config").LinkStyle

---@class cmp_obsidian.CompletionItem
---@field label string
---@field new_text string
---@field sort_text string
---@field documentation table|?

---@class cmp_obsidian.Source : obsidian.ABC
local source = abc.new_class()

source.new = function()
  return source.init()
end

source.get_trigger_characters = completion.get_trigger_characters

source.get_keyword_pattern = completion.get_keyword_pattern

source.complete = function(_, request, callback)
  local client = assert(obsidian.get_client())
  local can_complete, search, insert_start, insert_end, ref_type = completion.can_complete(request)

  if not (can_complete and search ~= nil and #search >= client.opts.completion.min_chars) then
    callback { isIncomplete = true }
    return
  end

  local in_buffer_only = false

  ---@type string|?
  local block_link
  search, block_link = util.strip_block_links(search)

  ---@type string|?
  local anchor_link
  search, anchor_link = util.strip_anchor_links(search)

  -- If block link is incomplete, we'll match against all block links.
  if not block_link and vim.endswith(search, "#^") then
    block_link = "#^"
    search = string.sub(search, 1, -3)
  end

  -- If anchor link is incomplete, we'll match against all anchor links.
  if not anchor_link and vim.endswith(search, "#") then
    anchor_link = "#"
    search = string.sub(search, 1, -2)
  end

  if (anchor_link or block_link) and string.len(search) == 0 then
    -- Search over headers/blocks in current buffer only.
    in_buffer_only = true
  end

  ---@param results obsidian.Note[]
  local function search_callback(results)
    -- Completion items.
    local items = {}

    ---@type table<string, cmp_obsidian.CompletionItem>
    local new_text_to_option = {}

    for note in iter(results) do
      ---@cast note obsidian.Note

      -- Collect matching block links.
      ---@type obsidian.note.Block[]|?
      local matching_blocks
      if block_link then
        assert(note.blocks)
        matching_blocks = {}
        for block_id, block_data in pairs(note.blocks) do
          if vim.startswith("#" .. block_id, block_link) then
            table.insert(matching_blocks, block_data)
          end
        end

        if #matching_blocks == 0 then
          -- Unmatched, create a mock one.
          table.insert(matching_blocks, { id = util.standardize_block(block_link), line = 1 })
        end
      end

      -- Collect matching anchor links.
      ---@type obsidian.note.HeaderAnchor[]|?
      local matching_anchors
      if anchor_link then
        assert(note.anchor_links)
        matching_anchors = {}
        for anchor, anchor_data in pairs(note.anchor_links) do
          if vim.startswith(anchor, anchor_link) then
            table.insert(matching_anchors, anchor_data)
          end
        end

        if #matching_anchors == 0 then
          -- Unmatched, create a mock one.
          table.insert(
            matching_anchors,
            { anchor = anchor_link, header = string.sub(anchor_link, 2), level = 1, line = 1 }
          )
        end
      end

      ---@param label string|?
      ---@param alt_label string|?
      local function update_completion_options(label, alt_label)
        ---@type { label: string|?, alt_label: string|?, anchor: obsidian.note.HeaderAnchor|?, block: obsidian.note.Block|? }[]
        local new_options = {}
        if matching_anchors ~= nil then
          for anchor in iter(matching_anchors) do
            table.insert(new_options, { label = label, alt_label = alt_label, anchor = anchor })
          end
        elseif matching_blocks ~= nil then
          for block in iter(matching_blocks) do
            table.insert(new_options, { label = label, alt_label = alt_label, block = block })
          end
        else
          if label then
            table.insert(new_options, { label = label, alt_label = alt_label })
          end

          -- Add all blocks and anchors, let cmp sort it out.
          for _, anchor_data in pairs(note.anchor_links or {}) do
            table.insert(new_options, { label = label, alt_label = alt_label, anchor = anchor_data })
          end
          for _, block_data in pairs(note.blocks or {}) do
            table.insert(new_options, { label = label, alt_label = alt_label, block = block_data })
          end
        end

        -- De-duplicate options relative to their `new_text`.
        for _, option in ipairs(new_options) do
          ---@type obsidian.config.LinkStyle
          local link_style
          if ref_type == completion.RefType.Wiki then
            link_style = LinkStyle.wiki
          elseif ref_type == completion.RefType.Markdown then
            link_style = LinkStyle.markdown
          else
            error "not implemented"
          end

          ---@type string, string, string, table|?
          local final_label, sort_text, new_text, documentation
          if option.label then
            new_text = client:format_link(
              note,
              { label = option.label, link_style = link_style, anchor = option.anchor, block = option.block }
            )

            final_label = assert(option.alt_label or option.label)
            if option.anchor then
              final_label = final_label .. option.anchor.anchor
            elseif option.block then
              final_label = final_label .. "#" .. option.block.id
            end
            sort_text = final_label

            documentation = {
              kind = "markdown",
              value = note:display_info {
                label = new_text,
                anchor = option.anchor,
                block = option.block,
              },
            }
          elseif option.anchor then
            -- In buffer anchor link.
            -- TODO: allow users to customize this?
            if ref_type == completion.RefType.Wiki then
              new_text = "[[#" .. option.anchor.header .. "]]"
            elseif ref_type == completion.RefType.Markdown then
              new_text = "[#" .. option.anchor.header .. "](" .. option.anchor.anchor .. ")"
            else
              error "not implemented"
            end

            final_label = option.anchor.anchor
            sort_text = final_label

            documentation = {
              kind = "markdown",
              value = string.format("`%s`", new_text),
            }
          elseif option.block then
            -- In buffer block link.
            -- TODO: allow users to customize this?
            if ref_type == completion.RefType.Wiki then
              new_text = "[[#" .. option.block.id .. "]]"
            elseif ref_type == completion.RefType.Markdown then
              new_text = "[#" .. option.block.id .. "](#" .. option.block.id .. ")"
            else
              error "not implemented"
            end

            final_label = "#" .. option.block.id
            sort_text = final_label

            documentation = {
              kind = "markdown",
              value = string.format("`%s`", new_text),
            }
          else
            error "should not happen"
          end

          if new_text_to_option[new_text] then
            new_text_to_option[new_text].sort_text = new_text_to_option[new_text].sort_text .. " " .. sort_text
          else
            new_text_to_option[new_text] =
              { label = final_label, new_text = new_text, sort_text = sort_text, documentation = documentation }
          end
        end
      end

      if in_buffer_only then
        update_completion_options()
      else
        -- Collect all valid aliases for the note, including ID, title, and filename.
        ---@type string[]
        local aliases
        if not in_buffer_only then
          aliases = util.tbl_unique { tostring(note.id), note:display_name(), unpack(note.aliases) }
          if note.title ~= nil then
            table.insert(aliases, note.title)
          end
        end

        for alias in iter(aliases) do
          update_completion_options(alias)
          local alias_case_matched = util.match_case(search, alias)

          if
            alias_case_matched ~= nil
            and alias_case_matched ~= alias
            and not util.tbl_contains(note.aliases, alias_case_matched)
          then
            update_completion_options(alias_case_matched)
          end
        end

        if note.alt_alias ~= nil then
          update_completion_options(note:display_name(), note.alt_alias)
        end
      end
    end

    for _, option in pairs(new_text_to_option) do
      -- TODO: need a better label, maybe just the note's display name?
      ---@type string
      local label
      if ref_type == completion.RefType.Wiki then
        label = string.format("[[%s]]", option.label)
      elseif ref_type == completion.RefType.Markdown then
        label = string.format("[%s](…)", option.label)
      else
        error "not implemented"
      end

      table.insert(items, {
        documentation = option.documentation,
        sortText = option.sort_text,
        label = label,
        kind = 18, -- "Reference"
        textEdit = {
          newText = option.new_text,
          range = {
            start = {
              line = request.context.cursor.row - 1,
              character = insert_start,
            },
            ["end"] = {
              line = request.context.cursor.row - 1,
              character = insert_end,
            },
          },
        },
      })
    end

    callback {
      items = items,
      isIncomplete = true,
    }
  end

  if in_buffer_only then
    local note = client:current_note(0, { collect_anchor_links = true, collect_blocks = true })
    if note then
      search_callback { note }
    else
      callback { isIncomplete = true }
    end
  else
    client:find_notes_async(search, search_callback, {
      search = { ignore_case = true },
      notes = { collect_anchor_links = anchor_link ~= nil, collect_blocks = block_link ~= nil },
    })
  end
end

return source
