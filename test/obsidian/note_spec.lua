local Note = require "obsidian.note"
local util = require "obsidian.util"

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
    assert.equals(note:fname(), "foo.md")
    assert.is_true(note.has_frontmatter)
    assert(#note.tags == 0)
  end)
  it("should be able to be initialized from a README", function()
    local note = Note.from_file "README.md"
    assert.equals(note.id, "README.md")
    assert.equals(#note.aliases, 1)
    assert.equals(note.aliases[1], "Obsidian.nvim")
    assert.equals(#note.tags, 0)
    assert.equals(note:fname(), "README.md")
    assert.is_false(note:should_save_frontmatter())
  end)
  it("should be able to be initialized from a note w/o frontmatter", function()
    local note = Note.from_file "test_fixtures/notes/note_without_frontmatter.md"
    assert.equals(note.id, "test_fixtures/notes/note_without_frontmatter.md")
    assert.equals(#note.aliases, 1)
    assert.equals(note.aliases[1], "Hey there")
    assert.equals(#note.tags, 0)
    assert.is_not(note:fname(), nil)
    assert.is_false(note.has_frontmatter)
    assert.is_true(note:should_save_frontmatter())
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
  it("should be able to save note w/o frontmatter to file", function()
    local note = Note.from_file "test_fixtures/notes/note_without_frontmatter.md"
    note:save "./test_fixtures/notes/note_without_frontmatter_saved.md"
  end)
  it("should be able to save a new note", function()
    local note = Note.new("FOO", {}, {}, "/tmp/" .. util.zettel_id() .. ".md")
    note:save()
  end)
  it("should be able to parse a markdown header", function()
    assert.equals(Note._parse_header "## Hey there", "Hey there")
  end)
  it("should be able to find a frontmatter boundary", function()
    assert.is_true(Note._is_frontmatter_boundary "---")
    assert.is_true(Note._is_frontmatter_boundary "----")
  end)
  it("should be able to be initialize and save a note with additional frontmatter metadata", function()
    local note = Note.from_file "test_fixtures/notes/note_with_additional_metadata.md"
    assert.equals(note.id, "note_with_additional_metadata")
    assert.is_not(note.metadata, nil)
    assert.equals(note.metadata.foo, "bar")
    assert.equals(
      table.concat(note:frontmatter_lines(), "\n"),
      table.concat({
        "---",
        'id: "note_with_additional_metadata"',
        "aliases:",
        '  - "Note with additional metadata"',
        "tags: []",
        'foo: "bar"',
        "---",
      }, "\n")
    )
    note:save "./test_fixtures/notes/note_with_additional_metadata_saved.md"
  end)
end)
