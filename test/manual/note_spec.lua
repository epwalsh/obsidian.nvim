----------------------------
-- Testing the Note class --
----------------------------

local obsidian = require "obsidian"

-- Test note.new():
local n1 = obsidian.Note.new("FOO", { "foo", "foos" }, { "bar" })
assert(n1.id == "FOO")
assert(n1.aliases[1] == "foo")

-- Test note.from_file():
local n2 = obsidian.Note.from_file "test/fixtures/notes/foo.md"
assert(n2.id == "foo")
assert(n2.aliases[1] == "foo")
assert(n2.aliases[2] == "Foo")
assert(#n2.tags == 0)

-- Add an alias and update the file:
n2:add_alias "Foo Bar"
n2:save "test/fixtures/notes/foo_bar.md"
