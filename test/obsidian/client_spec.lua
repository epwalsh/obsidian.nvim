local Path = require "plenary.path"
local obsidian = require "obsidian"

---Get a client in a temporary directory.
---
---@return obsidian.Client
local tmp_client = function()
  -- This gives us a tmp file name, but we really want a directory.
  -- So we delete that file immediately.
  local tmpname = os.tmpname()
  os.remove(tmpname)

  local dir = Path:new(tmpname .. "-obsidian/")
  dir:mkdir { parents = true }

  return obsidian.new_from_dir(tostring(dir))
end

describe("Client", function()
  it("should be able to initialize a daily note", function()
    local client = tmp_client()
    local note = client:today()
    assert.is_true(note.path ~= nil)
    assert.is_true(note:exists())
  end)
end)
