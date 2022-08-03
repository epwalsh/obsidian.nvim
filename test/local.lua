local obsidian = require("obsidian")

-- Testing the Note class.
--------------------------

-- Test note.new():
local n1 = obsidian.note.new("FOO", { "foo", "foos" }, { "bar" })
assert(n1.id == "FOO")
assert(n1.aliases[1] == "foo")

-- Test note.from_file():
local n2 = obsidian.note.from_file("test_fixtures/notes/foo.md")
assert(n2.id == "foo")
assert(n2.aliases[1] == "foo")
assert(n2.aliases[2] == "Foo")
assert(#n2.tags == 0)

-- Add an alias and update the file:
n2:add_alias("Foo Bar")
n2:save("test_fixtures/notes/foo_bar.md")

-- Testing the Client cache.
----------------------------

-- Test obsidian.setup():
local client = obsidian.setup({ dir = "/tmp/notes" })
client.cache:clear()

-- Test client.cache:set():
client.cache:set(n1)
assert(client.cache:size() == 1)
assert(client.cache.db.aliases:count() == 2)
assert(client.cache.db.tags:count() == 1)

-- Test client.cache:contains():
assert(client.cache:contains(n1.id))

-- Test client.cache:get():
local cached_n1 = client.cache:get(n1.id)
assert(cached_n1.id == n1.id)

-- Update existing note.
n1:add_alias("baz")
client.cache:set(n1)
assert(client.cache:size() == 1)
assert(client.cache.db.aliases:count() == 3)

-- Test remove.
client.cache:remove(n1.id)
assert(client.cache:contains(n1.id) == false)

-- Test remove an non-existing item.
client.cache:remove("FOO-BAR")

-- Test clear the cache.
client.cache:clear()
assert(client.cache:size() == 0)

-- Search by alias.
client.cache:set(obsidian.note.new("FOO", { "foo" }, { "baztag", "bartag" }))
client.cache:set(obsidian.note.new("BAR", { "bar" }, { "bartag" }))
local s1 = client.cache:search_alias("foo")
assert(#s1 == 1)
assert(s1[1].id == "FOO")

-- -- Search by alias with multiple hits.
client.cache:set(obsidian.note.new("FOOBAR", { "foobar" }, {}))
local s2 = client.cache:search_alias("foo")
assert(#s2 == 2)

-- -- Search by tags.
local s3 = client.cache:search_tag("bartag")
assert(#s3 == 2, #s3)
