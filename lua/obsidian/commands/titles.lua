local log = require "obsidian.log"
local util = require "obsidian.util"

---@param notes obsidian.Note[]
---
---@return obsidian.PickerEntry[]
local function convert_notes_to_picker_entries(notes)
  ---@type obsidian.PickerEntry[]
  local entries = {}

  for _, note in ipairs(notes) do
    local title = note.title

    if title then
      entries[#entries + 1] = {
        value = note,
        display = title,
        ordinal = note:display_name() .. " " .. title,
        filename = tostring(note.path),
      }
    end

    for _, alias in ipairs(note.aliases) do
      if alias ~= title then
        entries[#entries + 1] = {
          value = note,
          display = alias,
          ordinal = note:display_name() .. " " .. alias,
          filename = tostring(note.path),
        }
      end
    end
  end

  return entries
end

---@param client obsidian.Client
return function(client)
  local picker = client:picker()
  if not picker then
    log.err "No picker configured"
    return
  end

  client:find_notes_async("", function(notes)
    vim.schedule(function()
      picker:pick(convert_notes_to_picker_entries(notes), {
        prompt_title = "Titles",
        callback = function(...)
          for _, note in ipairs { ... } do
            util.open_buffer(note.path)
          end
        end,
        allow_multiple = true,
      })
    end)
  end)
end
