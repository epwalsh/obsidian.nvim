local abc = require "obsidian.abc"
local completion = require "obsidian.completion.refs"
local obsidian = require "obsidian"
local util = require "obsidian.util"
local iter = require("obsidian.itertools").iter
local LinkStyle = require("obsidian.config").LinkStyle

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

  ---@type string|?
  local anchor_link
  search, anchor_link = util.strip_anchor_links(search)

  ---@param results obsidian.Note[]
  local function search_callback(results)
    -- Completion items.
    local items = {}

    for note in iter(results) do
      ---@cast note obsidian.Note
      assert(note.anchor_links)

      -- Collect matching anchor links.
      ---@type { anchor: string, header: string|? }[]|?
      local matching_anchors
      if anchor_link then
        matching_anchors = {}
        for anchor, anchor_data in pairs(note.anchor_links) do
          if vim.startswith(anchor, anchor_link) then
            table.insert(matching_anchors, { anchor = anchor, header = anchor_data.header })
          end
        end

        if #matching_anchors == 0 then
          table.insert(matching_anchors, { anchor = anchor_link })
        end
      end

      -- Collect all valid aliases for the note, including ID, title, and filename.
      local aliases = util.tbl_unique { tostring(note.id), note:display_name(), unpack(note.aliases) }
      if note.title ~= nil then
        table.insert(aliases, note.title)
      end

      -- Transform aliases into completion options.
      ---@type { label: string, anchor: string|?, header: string|? }[]
      local completion_options = {}

      ---@param option string
      local function update_completion_options(option)
        if matching_anchors ~= nil then
          for anchor in iter(matching_anchors) do
            table.insert(completion_options, { label = option, anchor = anchor.anchor, header = anchor.header })
          end
        else
          table.insert(completion_options, { label = option })

          -- Add all anchors, let cmp sort it out.
          for anchor, anchor_data in pairs(note.anchor_links) do
            table.insert(completion_options, { label = option, anchor = anchor, header = anchor_data.header })
          end
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

      ---@cast note obsidian.Note
      ---@type table<string, boolean>
      local labels_seen = {}
      for option in iter(completion_options) do
        ---@type obsidian.config.LinkStyle
        local link_style
        if ref_type == completion.RefType.Wiki then
          link_style = LinkStyle.wiki
        elseif ref_type == completion.RefType.Markdown then
          link_style = LinkStyle.markdown
        else
          error "not implemented"
        end

        local label = client:format_link(
          note,
          { label = option.label, link_style = link_style, anchor = option.anchor, header = option.header }
        )

        if not labels_seen[label] then
          labels_seen[label] = true

          ---@type string
          local sort_text
          if ref_type == completion.RefType.Wiki then
            sort_text = "[[" .. option.label
          elseif ref_type == completion.RefType.Markdown then
            sort_text = "[" .. option.label
          else
            error "not implemented"
          end

          table.insert(items, {
            documentation = { kind = "markdown", value = note:display_info { label = option.label } },
            sortText = sort_text,
            label = label,
            kind = 18, -- "Reference"
            textEdit = {
              newText = label,
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
      end
    end

    callback {
      items = items,
      isIncomplete = false,
    }
  end

  client:find_notes_async(
    search,
    search_callback,
    { search = { ignore_case = true }, notes = { collect_anchor_links = true } }
  )
end

return source
