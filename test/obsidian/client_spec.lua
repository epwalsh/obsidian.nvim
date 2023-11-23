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

  local client = obsidian.new_from_dir(tostring(dir))
  client.opts.note_id_func = function(title)
    local id = ""
    if title ~= nil then
      id = title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
    else
      for _ = 1, 4 do
        id = id .. string.char(math.random(65, 90))
      end
    end
    return id
  end

  return client
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

  it("should parse a title that's a partial path", function()
    local client = tmp_client()
    local title, id, path = client:parse_title_id_path "notes/Foo"
    assert.equals(title, "Foo")
    assert.equals(id, "foo")
    assert.equals(tostring(path), tostring(Path:new(client.dir) / "notes" / "foo.md"))
  end)

  it("should parse a title that's an exact path", function()
    local client = tmp_client()
    local title, id, path = client:parse_title_id_path "notes/foo.md"
    assert.equals(title, "foo")
    assert.equals(id, "foo")
    assert.equals(tostring(path), tostring(Path:new(client.dir) / "notes" / "foo.md"))
  end)

  it("should ignore boundary whitespace when parsing a title", function()
    local client = tmp_client()
    local title, id, path = client:parse_title_id_path "notes/Foo  "
    assert.equals(title, "Foo")
    assert.equals(id, "foo")
    assert.equals(tostring(path), tostring(Path:new(client.dir) / "notes" / "foo.md"))
  end)

  it("should keep whitespace within a path when parsing a title", function()
    local client = tmp_client()
    local title, id, path = client:parse_title_id_path "notes/Foo Bar.md"
    assert.equals(title, "Foo Bar")
    assert.equals(id, "Foo Bar")
    assert.equals(tostring(path), tostring(Path:new(client.dir) / "notes" / "Foo Bar.md"))
  end)

  it("should generate a new id when the title is just a folder", function()
    local client = tmp_client()
    local title, id, path = client:parse_title_id_path "notes/"
    assert.equals(title, nil)
    assert.equals(#id, 4)
    assert.equals(tostring(path), tostring(Path:new(client.dir) / "notes" / (id .. ".md")))
  end)

  it("should prepare search opts properly", function()
    local client = tmp_client()
    local opts = client:_prepare_search_opts(true, { max_count_per_file = 1 })
    assert.are_same(opts:to_ripgrep_opts(), { "--sortr=modified", "-m=1" })
  end)
end)
