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

  if can_complete and search ~= nil and #search >= client.opts.completion.min_chars then
    local function search_callback(results)
      local items = {}
      for note in iter(results) do
        local labels_seen = {}

        local aliases = util.tbl_unique { tostring(note.id), note:display_name(), unpack(note.aliases) }
        if note.title ~= nil and not util.tbl_contains(aliases, note.title) then
          aliases[#aliases + 1] = note.title
        end

        for alias in iter(aliases) do
          local options = {}

          local alias_case_matched = util.match_case(search, alias)
          if
            alias_case_matched ~= nil
            and alias_case_matched ~= alias
            and not util.tbl_contains(note.aliases, alias_case_matched)
          then
            table.insert(options, alias_case_matched)
          end

          table.insert(options, alias)

          for option in iter(options) do
            ---@type obsidian.config.LinkStyle
            local link_style
            if ref_type == completion.RefType.Wiki then
              link_style = LinkStyle.wiki
            elseif ref_type == completion.RefType.Markdown then
              link_style = LinkStyle.markdown
            else
              error "not implemented"
            end

            local label = client:format_link(note, { label = option, link_style = link_style })

            if not labels_seen[label] then
              ---@type string
              local sort_text
              if ref_type == completion.RefType.Wiki then
                sort_text = "[[" .. option
              elseif ref_type == completion.RefType.Markdown then
                sort_text = "[" .. option
              else
                error "not implemented"
              end

              table.insert(items, {
                documentation = { kind = "markdown", value = note:display_info { label = option } },
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

              labels_seen[label] = true
            end
          end
        end
      end

      callback {
        items = items,
        isIncomplete = false,
      }
    end

    client:find_notes_async(search, { ignore_case = true }, search_callback)
  else
    callback { isIncomplete = true }
  end
end

return source
