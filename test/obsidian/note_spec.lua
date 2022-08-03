local obsidian = require "obsidian"

describe("Note", function()
  it("should be able to be initialized directly", function()
    local note = obsidian.note.new("FOO", { "foo", "foos" }, { "bar" })
    assert(note.id == "FOO")
    assert(note.aliases[1] == "foo")
  end)
  it("should be able to be initialized from a file", function()
    local note = obsidian.note.from_file "test_fixtures/notes/foo.md"
    assert(note.id == "foo")
    assert(note.aliases[1] == "foo")
    assert(note.aliases[2] == "Foo")
    assert(#note.tags == 0)
  end)
  it("should be able to add an alias", function()
    local note = obsidian.note.from_file "test_fixtures/notes/foo.md"
    assert(#note.aliases == 2)
    note:add_alias "Foo Bar"
    assert(#note.aliases == 3)
  end)
  it("should be able to save to file", function()
    local note = obsidian.note.from_file "test_fixtures/notes/foo.md"
    note:add_alias "Foo Bar"
    note:save "./test_fixtures/notes/foo_bar.md"
  end)
end)
