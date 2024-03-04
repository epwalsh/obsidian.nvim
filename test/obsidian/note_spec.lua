---@diagnostic disable: invisible

local Note = require "obsidian.note"
local util = require "obsidian.util"
local async = require "plenary.async"

describe("Note.new()", function()
  it("should be able to be initialize directly", function()
    local note = Note.new("FOO", { "foo", "foos" }, { "bar" })
    assert.equals(note.id, "FOO")
    assert.equals(note.aliases[1], "foo")
    assert.is_true(Note.is_note_obj(note))
  end)
end)

describe("Note.from_file()", function()
  it("should work from a file", function()
    local note = Note.from_file "test/fixtures/notes/foo.md"
    assert.equals(note.id, "foo")
    assert.equals(note.aliases[1], "foo")
    assert.equals(note.aliases[2], "Foo")
    assert.equals(note:fname(), "foo.md")
    assert.is_true(note.has_frontmatter)
    assert(#note.tags == 0)
  end)

  it("should be able to collect anchor links", function()
    local note = Note.from_file("test/fixtures/notes/note_with_a_bunch_of_headers.md", { collect_anchor_links = true })
    assert.equals(note.id, "note_with_a_bunch_of_headers")
    assert.is_not(note.anchor_links, nil)

    assert.are_same({
      anchor = "#header-1",
      line = 5,
      header = "Header 1",
      level = 1,
    }, note.anchor_links["#header-1"])

    assert.are_same({
      anchor = "#sub-header-1-a",
      line = 7,
      header = "Sub header 1 A",
      level = 2,
      parent = note.anchor_links["#header-1"],
    }, note.anchor_links["#sub-header-1-a"])

    assert.are_same({
      anchor = "#header-2",
      line = 9,
      header = "Header 2",
      level = 1,
    }, note.anchor_links["#header-2"])

    assert.are_same({
      anchor = "#sub-header-2-a",
      line = 11,
      header = "Sub header 2 A",
      level = 2,
      parent = note.anchor_links["#header-2"],
    }, note.anchor_links["#sub-header-2-a"])

    assert.are_same({
      anchor = "#sub-header-3-a",
      line = 13,
      header = "Sub header 3 A",
      level = 2,
      parent = note.anchor_links["#header-2"],
    }, note.anchor_links["#sub-header-3-a"])

    assert.are_same({
      anchor = "#header-2#sub-header-3-a",
      line = 13,
      header = "Sub header 3 A",
      level = 2,
      parent = note.anchor_links["#header-2"],
    }, note.anchor_links["#header-2#sub-header-3-a"])

    assert.are_same({
      anchor = "#header-1",
      line = 5,
      header = "Header 1",
      level = 1,
    }, note:resolve_anchor_link "#header-1")

    assert.are_same({
      anchor = "#header-1",
      line = 5,
      header = "Header 1",
      level = 1,
    }, note:resolve_anchor_link "#Header 1")
  end)

  it("should be able to resolve anchor links after the fact", function()
    local note = Note.from_file("test/fixtures/notes/note_with_a_bunch_of_headers.md", { collect_anchor_links = false })
    assert.equals(note.id, "note_with_a_bunch_of_headers")
    assert.equals(nil, note.anchor_links)
    assert.are_same(
      { anchor = "#header-1", line = 5, header = "Header 1", level = 1 },
      note:resolve_anchor_link "#header-1"
    )
  end)

  it("should work from a README", function()
    local note = Note.from_file "README.md"
    assert.equals(note.id, "README")
    assert.equals(#note.tags, 0)
    assert.equals(note:fname(), "README.md")
    assert.is_false(note:should_save_frontmatter())
  end)

  it("should work from a file w/o frontmatter", function()
    local note = Note.from_file "test/fixtures/notes/note_without_frontmatter.md"
    assert.equals(note.id, "note_without_frontmatter")
    assert.equals(note.title, "Hey there")
    assert.equals(#note.aliases, 0)
    assert.equals(#note.tags, 0)
    assert.is_not(note:fname(), nil)
    assert.is_false(note.has_frontmatter)
    assert.is_true(note:should_save_frontmatter())
  end)

  it("should collect additional frontmatter metadata", function()
    local note = Note.from_file "test/fixtures/notes/note_with_additional_metadata.md"
    assert.equals(note.id, "note_with_additional_metadata")
    assert.is_not(note.metadata, nil)
    assert.equals(note.metadata.foo, "bar")
    assert.equals(
      table.concat(note:frontmatter_lines(), "\n"),
      table.concat({
        "---",
        "id: note_with_additional_metadata",
        "aliases: []",
        "tags: []",
        "foo: bar",
        "---",
      }, "\n")
    )
    note:save { path = "./test/fixtures/notes/note_with_additional_metadata_saved.md" }
  end)

  it("should be able to be read frontmatter that's formatted differently", function()
    local note = Note.from_file "test/fixtures/notes/note_with_different_frontmatter_format.md"
    assert.equals(note.id, "note_with_different_frontmatter_format")
    assert.is_not(note.metadata, nil)
    assert.equals(#note.aliases, 3)
    assert.equals(note.aliases[1], "Amanda Green")
    assert.equals(note.aliases[2], "Detective Green")
    assert.equals(note.aliases[3], "Mandy")
    assert.equals(note.title, "Detective")
  end)
end)

describe("Note.from_file_async()", function()
  it("should work from a file", function()
    async.util.block_on(function()
      local note = Note.from_file_async "test/fixtures/notes/foo.md"
      assert.equals(note.id, "foo")
      assert.equals(note.aliases[1], "foo")
      assert.equals(note.aliases[2], "Foo")
      assert.equals(note:fname(), "foo.md")
      assert.is_true(note.has_frontmatter)
      assert(#note.tags == 0)
    end, 1000)
  end)
end)

describe("Note.from_file_with_contents_async()", function()
  it("should work from a file", function()
    async.util.block_on(function()
      local note, contents = Note.from_file_with_contents_async "test/fixtures/notes/foo.md"
      assert.equals(note.id, "foo")
      assert.equals(note.aliases[1], "foo")
      assert.equals(note.aliases[2], "Foo")
      assert.equals(note:fname(), "foo.md")
      assert.is_true(note.has_frontmatter)
      assert(#note.tags == 0)
      assert.equals("---", contents[1])
    end, 1000)
  end)
end)

describe("Note:add_alias()", function()
  it("should be able to add an alias", function()
    local note = Note.from_file "test/fixtures/notes/foo.md"
    assert.equals(#note.aliases, 2)
    note:add_alias "Foo Bar"
    assert.equals(#note.aliases, 3)
  end)
end)

describe("Note.save()", function()
  it("should be able to save to file", function()
    local note = Note.from_file "test/fixtures/notes/foo.md"
    note:add_alias "Foo Bar"
    note:save { path = "./test/fixtures/notes/foo_bar.md" }
  end)

  it("should be able to save a note w/o frontmatter", function()
    local note = Note.from_file "test/fixtures/notes/note_without_frontmatter.md"
    note:save { path = "./test/fixtures/notes/note_without_frontmatter_saved.md" }
  end)

  it("should be able to save a new note", function()
    local note = Note.new("FOO", {}, {}, "/tmp/" .. util.zettel_id() .. ".md")
    note:save()
  end)
end)

describe("Note._is_frontmatter_boundary()", function()
  it("should be able to find a frontmatter boundary", function()
    assert.is_true(Note._is_frontmatter_boundary "---")
    assert.is_true(Note._is_frontmatter_boundary "----")
  end)
end)
