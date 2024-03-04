local log = require "obsidian.log"

---@param arg string
---@return number
local function parse_offset(arg)
  if vim.startswith(arg, "+") then
    return assert(tonumber(string.sub(arg, 2)), string.format("invalid offset '%'", arg))
  elseif vim.startswith(arg, "-") then
    return -assert(tonumber(string.sub(arg, 2)), string.format("invalid offset '%s'", arg))
  else
    return assert(tonumber(arg), string.format("invalid offset '%s'", arg))
  end
end

---@param client obsidian.Client
return function(client, data)
  local offset_start = -5
  local offset_end = 0

  if data.fargs and #data.fargs > 0 then
    if #data.fargs == 1 then
      local offset = parse_offset(data.fargs[1])
      if offset >= 0 then
        offset_end = offset
      else
        offset_start = offset
      end
    elseif #data.fargs == 2 then
      local offsets = vim.tbl_map(parse_offset, data.fargs)
      table.sort(offsets)
      offset_start = offsets[1]
      offset_end = offsets[2]
    else
      error ":ObsidianDailies expected at most 2 arguments"
    end
  end

  local picker = client:picker()
  if not picker then
    log.err "No picker configured"
    return
  end

  ---@type obsidian.PickerEntry[]
  local dailies = {}
  for offset = offset_end, offset_start, -1 do
    local datetime = os.time() + (offset * 3600 * 24)
    local daily_note_path = client:daily_note_path(datetime)
    local daily_note_alias = tostring(os.date(client.opts.daily_notes.alias_format or "%A %B %-d, %Y", datetime))
    if offset == 0 then
      daily_note_alias = daily_note_alias .. " @today"
    elseif offset == -1 then
      daily_note_alias = daily_note_alias .. " @yesterday"
    elseif offset == 1 then
      daily_note_alias = daily_note_alias .. " @tomorrow"
    end
    dailies[#dailies + 1] = {
      value = offset,
      display = daily_note_alias,
      ordinal = daily_note_alias,
      filename = tostring(daily_note_path),
    }
  end

  picker:pick(dailies, {
    prompt_title = "Dailies",
    callback = function(offset)
      local note = client:daily(offset)
      client:open_note(note)
    end,
  })
end
