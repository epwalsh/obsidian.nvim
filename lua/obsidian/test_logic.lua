-- Read target file
local filePath = "/Users/gomezaq/Repos/obsidian.nvim/test/fixtures/notes/note_with_callouts_2.md"

local ExtMark = {}
ExtMark.__index = ExtMark -- Set the metatable to use ExtMark as class

-- Constructor function to create a new ExtMark
function ExtMark:new(id, row, col, opts)
  local instance = setmetatable({}, ExtMark)
  instance.id = id or nil -- 'integer or nil', defaults to nil if not provided
  instance.row = row -- Must be an integer
  instance.col = col -- Must be an integer
  instance.opts = opts or {} -- Default to an empty table if no opts provided
  return instance
end

local ExtMarkOpts = {}
ExtMarkOpts.__index = ExtMarkOpts

---@param data table
---@return ExtMarkOpts
ExtMarkOpts.from_tbl = function(data)
  local self = setmetatable({}, ExtMarkOpts)
  self.end_row = data.end_row
  self.end_col = data.end_col
  self.conceal = data.conceal
  self.hl_group = data.hl_group
  self.spell = data.spell
  return self
end

local test_opts = {
  callouts = {
    ["note"] = {
      aliases = {},
      char = "",
      hl_group = "ObsidianCalloutNote",
    },
    ["abstract"] = {
      aliases = {
        "summary",
        "tldr",
      },
      char = "",
      hl_group = "ObsidianCalloutAbstract",
    },
    ["info"] = {
      aliases = {},
      char = "",
      hl_group = "ObsidianCalloutInfo",
    },
    ["todo"] = {
      aliases = {},
      char = "",
      hl_group = "ObsidianCalloutTodo",
    },
    ["tip"] = {
      aliases = {
        "hint",
        "important",
      },
      char = "󰈸",
      hl_group = "ObsidianCalloutTip",
    },
    ["success"] = {
      aliases = {
        "check",
        "done",
      },
      char = "󰄬",
      hl_group = "ObsidianCalloutSuccess",
    },
    ["question"] = {
      aliases = {
        "help",
        "faq",
      },
      char = "",
      hl_group = "ObsidianCalloutQuestion",
    },
    ["warning"] = {
      aliases = {
        "caution",
        "attentition",
      },
      char = "",
      hl_group = "ObsidianCalloutWarning",
    },
    ["failure"] = {
      aliases = {
        "fail",
        "missing",
      },
      char = "",
      hl_group = "ObsidianCalloutFailure",
    },
    ["danger"] = {
      aliases = {
        "error",
      },
      char = "",
      hl_group = "ObsidianCalloutDanger",
    },
    ["bug"] = {
      aliases = {},
      char = "",
      hl_group = "ObsidianCalloutBug",
    },
    ["example"] = {
      aliases = {},
      char = "",
      hl_group = "ObsidianCalloutExample",
    },
    ["quote"] = {
      aliases = {},
      char = "󱆨",
      hl_group = "ObsidianCalloutQuote",
    },
  },
}
local file = io.open(filePath, "r")
local callout_hl_group_stack = {}
local output_marks = {}

local count_indent = function(str)
  local indent = 0
  for i = 1, #str do
    local c = string.sub(str, i, i)
    -- space or tab both count as 1 indent
    if c == " " or c == "	" then
      indent = indent + 1
    else
      break
    end
  end
  return indent
end

local is_empty = function(table)
  return #table == 0
end

local function generate_callout_extmarks_body(marks, indent, line, lnum, callout_hl_group_stack)
  local highlight_grp_position = 0
  local start = indent

  while string.find(line, ">", start) ~= nil do
    highlight_grp_position = highlight_grp_position + 1
    local genExtMarks = ExtMarkOpts.from_tbl {
      end_row = lnum,
      conceal = "",
      hl_group = callout_hl_group_stack[highlight_grp_position],
    }

    -- If we have another > character, then we need to stop higlighting there
    local endPos = string.find(line, ">", start + 2)
    if endPos ~= nil then
      genExtMarks.end_col = endPos
    end

    marks[#marks + 1] = ExtMark.new(nil, lnum, start, genExtMarks)

    -- Update the start value to the end of current line
    start = start + 2
  end
end

local function generate_callout_extmarks_header(marks, indent, line, lnum, opts, callout_hl_group_stack)
  -- Function that checks if next char is the callout block
  local function isPatternMatch(str, position)
    local pattern = "%[%!%s*[%w%s]+%]%-%-?"
    local substring = string.sub(str, position)
    return string.find(substring, "^" .. pattern) ~= nil
  end

  local highlight_grp_position = 0
  local start = indent

  print("Generating header for" .. line)
  -- Handle highlights leading up to the header
  while string.find(line, ">", start) ~= nil do
    highlight_grp_position = highlight_grp_position + 1
    local genExtMarks = ExtMarkOpts.from_tbl {
      end_row = lnum,
      conceal = "",
      hl_group = callout_hl_group_stack[highlight_grp_position],
    }

    -- Handle highlighting until the next >
    local endPos = string.find(line, ">", start + 2)
    if endPos ~= nil then
      genExtMarks.end_col = endPos
    end
    marks[#marks + 1] = ExtMark.new(nil, lnum, start, genExtMarks)
    start = start + 2
    if isPatternMatch(line, start) ~= nil then
      break
    end
  end
  
  -- Conceal the [!..] mark
  local _, endHeader = string.find(line, "%]%-?", start)
  -- FIXME: This is mixing up rows, id, column, and opts
  local callout_mark_header = ExtMark.new(
    nil,
    lnum,
    start,
    ExtMarkOpts.from_tbl {
      end_row = lnum,
      end_col = endHeader,
      conceal = opts.char,
      hl_group = opts.hl_group,
    }
  )
  marks[#marks + 1] = callout_mark_header
end

local function get_callout_hl_group(line, ui_opts)
  local lower_line = string.lower(line)
  local function constructed_text(word)
    return "[!" .. word .. "]"
  end

  for calloutWord, opts in pairs(ui_opts.callouts) do
    if string.find(lower_line, constructed_text(calloutWord), 1, true) then
      return opts.hl_group
    end
    for _, alias in ipairs(opts.aliases) do
      if string.find(lower_line, constructed_text(alias), 1, true) then
        return opts.hl_group
      end
    end
  end
  return ""
end

if file then
  -- Create stack
  local lines = {}
  for line in file:lines() do
    table.insert(lines, line)
  end

  print "Building stack"
  for _, line in ipairs(lines) do
    if string.match(line, "%s*>%s*%[%!.-%]%s*(.+)") then
      table.insert(callout_hl_group_stack, get_callout_hl_group(line, test_opts))
    end
  end

  print "Checking lines:"
  for _, line in ipairs(lines) do
    local lower_line = string.lower(line)
    local indent = count_indent(line)

    if string.match(line, "%s*>%s*%[%!.-%]%s*(.+)") then
      for calloutWord, opts in pairs(test_opts.callouts) do
        local constructed_text = "[!" .. calloutWord .. "]"
        if string.find(lower_line, constructed_text, 1, true) then
          generate_callout_extmarks_header(output_marks, indent, line, 1, opts, callout_hl_group_stack)
          break
        end
        for _, alias in ipairs(opts.aliases) do
          local alias_constructed_text = "[!" .. alias .. "]"
          if string.find(lower_line, alias_constructed_text, 1, true) then
            generate_callout_extmarks_header(output_marks, indent, line, 1, opts, callout_hl_group_stack)
            break
          end
        end
      end
    -- If we have a current stack, then we're in a callout group and should apply it
    elseif
      string.find(line, ">")
      and not is_empty(callout_hl_group_stack)
    then
      generate_callout_extmarks_body(output_marks, indent, line, 1, callout_hl_group_stack)

    -- If we have a current stack, but the we don't match the > block, then we should remove all of the items from the stack
    -- as this inidcates we've exited the existing callout block
    elseif not string.match(line, "%s*>(.+)") and not is_empty(callout_hl_group_stack) then
      for k in pairs(callout_hl_group_stack) do
        callout_hl_group_stack[k] = nil
      end
    end
  end

  for _, value in ipairs(output_marks) do
    print(value)
  end
  file:close()
end
