local Path = require "obsidian.path"
local Note = require "obsidian.note"
local obsidian = require "obsidian"

---Get a client in a temporary directory.
---
---@param run fun(client: obsidian.Client)
local with_tmp_client = function(run)
  local dir = Path.temp { suffix = "-obsidian" }
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

  local ok, err = pcall(run, client)

  dir:rmtree()

  if not ok then
    error(err)
  end
end

describe("Client", function()
  it("should be able to initialize a daily note", function()
    with_tmp_client(function(client)
      local note = client:today()
      assert.is_true(note.path ~= nil)
      assert.is_true(note:exists())
    end)
  end)

  it("should not add frontmatter for today when disabled", function()
    with_tmp_client(function(client)
      client.opts.disable_frontmatter = true
      local new_note = client:today()

      local saved_note = Note.from_file(new_note.path)
      assert.is_false(saved_note.has_frontmatter)
    end)
  end)

  it("should not add frontmatter for yesterday when disabled", function()
    with_tmp_client(function(client)
      client.opts.disable_frontmatter = true
      local new_note = client:yesterday()

      local saved_note = Note.from_file(new_note.path)
      assert.is_false(saved_note.has_frontmatter)
    end)
  end)

  it("should parse a title that's a partial path and generate new ID", function()
    with_tmp_client(function(client)
      local title, id, path = client:parse_title_id_path "notes/Foo"
      assert.equals(title, "Foo")
      assert.equals(id, "foo")
      assert.equals(tostring(path), tostring(Path:new(client.dir) / "notes" / "foo.md"))
    end)
  end)

  it("should parse an ID that's a path", function()
    with_tmp_client(function(client)
      local title, id, path = client:parse_title_id_path("Foo", "notes/1234-foo")
      assert.equals(title, "Foo")
      assert.equals(id, "1234-foo")
      assert.equals(tostring(path), tostring(Path:new(client.dir) / "notes" / "1234-foo.md"))
    end)
  end)

  it("should parse a title that's an exact path", function()
    with_tmp_client(function(client)
      local title, id, path = client:parse_title_id_path "notes/foo.md"
      assert.equals(title, "foo")
      assert.equals(id, "foo")
      assert.equals(tostring(path), tostring(Path:new(client.dir) / "notes" / "foo.md"))
    end)
  end)

  it("should ignore boundary whitespace when parsing a title", function()
    with_tmp_client(function(client)
      local title, id, path = client:parse_title_id_path "notes/Foo  "
      assert.equals(title, "Foo")
      assert.equals(id, "foo")
      assert.equals(tostring(path), tostring(Path:new(client.dir) / "notes" / "foo.md"))
    end)
  end)

  it("should keep whitespace within a path when parsing a title", function()
    with_tmp_client(function(client)
      local title, id, path = client:parse_title_id_path "notes/Foo Bar.md"
      assert.equals(title, "Foo Bar")
      assert.equals(id, "Foo Bar")
      assert.equals(tostring(path), tostring(Path:new(client.dir) / "notes" / "Foo Bar.md"))
    end)
  end)

  it("should generate a new id when the title is just a folder", function()
    with_tmp_client(function(client)
      local title, id, path = client:parse_title_id_path "notes/"
      assert.equals(title, nil)
      assert.equals(#id, 4)
      assert.equals(tostring(path), tostring(Path:new(client.dir) / "notes" / (id .. ".md")))
    end)
  end)

  it("should prepare search opts properly", function()
    with_tmp_client(function(client)
      ---@diagnostic disable-next-line: invisible
      local opts = client:_prepare_search_opts(true, { max_count_per_file = 1 })
      assert.are_same(opts:to_ripgrep_opts(), { "--sortr=modified", "-m=1" })
    end)
  end)

  it("should resolve relative paths", function()
    with_tmp_client(function(client)
      assert.are_same(client:vault_relative_path "foo.md", Path.new "foo.md")
      assert.are_same(client:vault_relative_path(client.dir / "foo.md"), Path.new "foo.md")
    end)
  end)
end)
