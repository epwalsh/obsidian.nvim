local Note = require "obsidian.note"

describe("Note", function()
  it("should be able to be initialized directly", function()
    local note = Note.new("FOO", { "foo", "foos" }, { "bar" })
    assert.equals(note.id, "FOO")
    assert.equals(note.aliases[1], "foo")
  end)
  it("should be able to be initialized from a file", function()
    local note = Note.from_file "test_fixtures/notes/foo.md"
    assert.equals(note.id, "foo")
    assert.equals(note.aliases[1], "foo")
    assert.equals(note.aliases[2], "Foo")
    assert(#note.tags == 0)
  end)
  it("should be able to be initialized from a README", function()
    local note = Note.from_file "README.md"
    assert.equals(note.id, "README.md")
    assert.equals(#note.aliases, 1)
    assert.equals(note.aliases[1], "Obsidian.nvim")
    assert.equals(#note.tags, 0)
  end)
  it("should be able to be initialized from a note w/o frontmatter", function()
    local note = Note.from_file "test_fixtures/notes/note_without_frontmatter.md"
    assert.equals(note.id, "test_fixtures/notes/note_without_frontmatter.md")
    assert.equals(#note.aliases, 1)
    assert.equals(note.aliases[1], "Hey there")
    assert.equals(#note.tags, 0)
  end)
  it("should be able to add an alias", function()
    local note = Note.from_file "test_fixtures/notes/foo.md"
    assert.equals(#note.aliases, 2)
    note:add_alias "Foo Bar"
    assert.equals(#note.aliases, 3)
  end)
  it("should be able to save to file", function()
    local note = Note.from_file "test_fixtures/notes/foo.md"
    note:add_alias "Foo Bar"
    note:save "./test_fixtures/notes/foo_bar.md"
  end)
  it("should be able to parse a markdown header", function()
    assert.equals(Note._parse_header "## Hey there", "Hey there")
  end)
  it("should be able to find a frontmatter boundary", function()
    assert.is_true(Note._is_frontmatter_boundary "---")
    assert.is_true(Note._is_frontmatter_boundary "----")
  end)
end)
