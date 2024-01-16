local abc = require "obsidian.abc"
local completion = require "obsidian.completion.refs"
local obsidian = require "obsidian"
local log = require "obsidian.log"
local util = require "obsidian.util"
local iter = require("obsidian.itertools").iter

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

        local aliases
        if client.opts.completion.use_path_only then
          aliases = { note.id }
        else
          aliases = util.tbl_unique { tostring(note.id), note:display_name(), unpack(note.aliases) }
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
            local rel_path = assert(client:vault_relative_path(note.path))
            if vim.endswith(rel_path, ".md") then
              rel_path = string.sub(rel_path, 1, -4)
            end

            ---@type string
            local label
            if ref_type == completion.RefType.Wiki then
              if client.opts.completion.use_path_only then
                label = "[[" .. rel_path .. "]]"
              elseif client.opts.completion.prepend_note_path then
                label = "[[" .. rel_path
                if option ~= tostring(note.id) then
                  label = label .. "|" .. option .. "]]"
                else
                  label = label .. "]]"
                end
              elseif client.opts.completion.prepend_note_id then
                label = "[[" .. tostring(note.id)
                if option ~= tostring(note.id) then
                  label = label .. "|" .. option .. "]]"
                else
                  label = label .. "]]"
                end
              else
                log.err "Invalid completion options"
                return
              end
            elseif ref_type == completion.RefType.Markdown then
              label = "[" .. option .. "](" .. rel_path .. ".md)"
            else
              error "not implemented"
            end

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
                documentation = { kind = "markdown", value = note:display_info() },
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
