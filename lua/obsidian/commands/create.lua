local util = require "obsidian.util"
local log = require "obsidian.log"

-- Define 'parse_args' outside of the returned function
local function parse_args(input)
  local args = {}
  -- Adjusted pattern to account for quotes and non-space sequences
  for arg in input:gmatch '%b""' or input:gmatch "%S+" do
    -- Remove quotes from matched arguments
    arg = arg:gsub('"', "")
    table.insert(args, arg)
  end
  return args
end

-- Correctly structured return function
return function(client, data)
  -- Utilize the 'parse_args' function defined above
  local args = parse_args(data.args)

  local path = args[1]
  local title = args[2] -- This is optional

  -- If no path is provided, prompt for it
  if not path or path == "" then
    path = util.input "Enter path: "
    if not path or path == "" then
      log.warn "Path is required."
      return
    end
  end

  -- If only path is provided, optionally ask for a title
  if not title then
    title = util.input "Enter title (optional): "
    if title == "" then
      title = nil
    end -- Treat empty string as nil
  end

  -- Assuming 'create_note' can handle 'dir' for specifying path
  local note = client:create_note { title = title, dir = path, no_write = false }

  -- Open the note in a new buffer
  client:open_note(note, { sync = true })
end
