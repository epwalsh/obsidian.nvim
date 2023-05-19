local Path = require "plenary.path"
local Note = require "obsidian.note"
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

  it("should not add frontmatter for today when disabled", function()
    local client = tmp_client()
    client.opts.disable_frontmatter = true
    local new_note = client:today()

    local saved_note = Note.from_file(new_note.path)
    assert.is_false(saved_note.has_frontmatter)
  end)

  it("should not add frontmatter for yesterday when disabled", function()
    local client = tmp_client()
    client.opts.disable_frontmatter = true
    local new_note = client:yesterday()

    local saved_note = Note.from_file(new_note.path)
    assert.is_false(saved_note.has_frontmatter)
  end)
end)
