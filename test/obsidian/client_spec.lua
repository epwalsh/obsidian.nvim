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
end)

describe("Client:parse_title_id_path()", function()
  it("should parse a title that's a partial path and generate new ID", function()
    with_tmp_client(function(client)
      local title, id, path = client:parse_title_id_path "notes/Foo"
      assert.equals("Foo", title)
      assert.equals("foo", id)
      assert.equals(Path:new(client.dir) / "notes" / "foo.md", path)

      title, id, path = client:parse_title_id_path "notes/New Title"
      assert.equals("New Title", title)
      assert.equals("new-title", id)
      assert.equals(Path:new(client.dir) / "notes" / "new-title.md", path)
    end)
  end)

  it("should interpret relative directories relative to vault root.", function()
    with_tmp_client(function(client)
      local title, id, path = client:parse_title_id_path("Foo", nil, "new-notes")
      assert.equals(title, "Foo")
      assert.equals(id, "foo")
      assert.equals(path, Path:new(client.dir) / "new-notes" / "foo.md")
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

  it("should respect configured 'note_path_func'", function()
    with_tmp_client(function(client)
      client.opts.note_path_func = function(spec)
        return (spec.dir / "foo-bar-123"):with_suffix ".md"
      end

      local title, id, path = client:parse_title_id_path "New Note"
      assert.equals("New Note", title)
      assert.equals("new-note", id)
      assert.equals(Path:new(client.dir) / "foo-bar-123.md", path)
    end)
  end)

  it("should ensure result of 'note_path_func' always has '.md' suffix", function()
    with_tmp_client(function(client)
      client.opts.note_path_func = function(spec)
        return spec.dir / "foo-bar-123"
      end

      local title, id, path = client:parse_title_id_path "New Note"
      assert.equals("New Note", title)
      assert.equals("new-note", id)
      assert.equals(Path:new(client.dir) / "foo-bar-123.md", path)
    end)
  end)

  it("should ensure result of 'note_path_func' is always an absolute path and within provided directory", function()
    with_tmp_client(function(client)
      client.opts.note_path_func = function(_)
        return "foo-bar-123.md"
      end;

      (client.dir / "notes"):mkdir { exist_ok = true }

      local title, id, path = client:parse_title_id_path("New Note", nil, client.dir / "notes")
      assert.equals("New Note", title)
      assert.equals("new-note", id)
      assert.equals(Path:new(client.dir) / "notes" / "foo-bar-123.md", path)
    end)
  end)
end)

describe("Client:_prepare_search_opts()", function()
  it("should prepare search opts properly", function()
    with_tmp_client(function(client)
      ---@diagnostic disable-next-line: invisible
      local opts = client:_prepare_search_opts(true, { max_count_per_file = 1 })
      assert.are_same(opts:to_ripgrep_opts(), { "--sortr=modified", "-m=1" })
    end)
  end)
end)

describe("Client:vault_relative_path()", function()
  it("should resolve relative paths", function()
    with_tmp_client(function(client)
      assert.are_same(client:vault_relative_path "foo.md", Path.new "foo.md")
      assert.are_same(client:vault_relative_path(client.dir / "foo.md"), Path.new "foo.md")
    end)
  end)

  it("should error when strict=true and the relative path can't be resolved", function()
    with_tmp_client(function(client)
      assert.has_error(function()
        client:vault_relative_path("/Users/petew/foo.md", { strict = true })
      end)
    end)
  end)

  it("should not error when strict=false and the relative path can't be resolved", function()
    with_tmp_client(function(client)
      assert.is_nil(client:vault_relative_path "/Users/petew/foo.md")
    end)
  end)
end)

describe("Client:create_note()", function()
  it("should create a new note with or without aliases and tags", function()
    with_tmp_client(function(client)
      local note = client:create_note { title = "Foo", aliases = { "Bar" }, tags = { "note" } }
      assert.equals(note.title, "Foo")
      assert.are_same(note.aliases, { "Bar", "Foo" })
      assert.are_same(note.tags, { "note" })
      assert.equals(note.path, client.dir / "foo.md")
    end)
  end)
end)

describe("Client:daily_note_path()", function()
  it("should use the path stem as the ID", function()
    with_tmp_client(function(client)
      client.opts.daily_notes.date_format = "%Y/%b/%Y-%m-%d"
      local path, id = client:daily_note_path()
      assert(vim.endswith(tostring(path), tostring(os.date("%Y/%b/%Y-%m-%d.md", os.time()))))
      assert.equals(id, os.date("%Y-%m-%d", os.time()))
    end)
  end)
end)
