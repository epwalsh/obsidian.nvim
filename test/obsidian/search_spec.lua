local async = require "plenary.async"
local channel = require("plenary.async.control").channel
local search = require "obsidian.search"
local util = require "obsidian.util"

local RefTypes = search.RefTypes
local SearchOpts = search.SearchOpts
local Patterns = search.Patterns

describe("search.find_notes_async()", function()
  it("should recursively find notes in a directory given a file name", function()
    async.util.block_on(function()
      local tx, rx = channel.oneshot()
      search.find_notes_async(".", "foo.md", function(matches)
        assert.equals(#matches, 1)
        assert.equals(tostring(matches[1]), util.resolve_path "./test_fixtures/notes/foo.md")
        tx()
      end)
      rx()
    end, 2000)
  end)
  it("should recursively find notes in a directory given a partial path", function()
    async.util.block_on(function()
      local tx, rx = channel.oneshot()
      search.find_notes_async(".", "notes/foo.md", function(matches)
        assert.equals(#matches, 1)
        assert.equals(tostring(matches[1]), util.resolve_path "./test_fixtures/notes/foo.md")
        tx()
      end)
      rx()
    end, 2000)
  end)
end)

describe("search.find_refs()", function()
  it("should find positions of all refs", function()
    local s = "[[Foo]] [[foo|Bar]]"
    assert.are_same({ { 1, 7, RefTypes.Wiki }, { 9, 19, RefTypes.WikiWithAlias } }, search.find_refs(s))
  end)

  it("should ignore refs within an inline code block", function()
    local s = "`[[Foo]]` [[foo|Bar]]"
    assert.are_same({ { 11, 21, RefTypes.WikiWithAlias } }, search.find_refs(s))

    s = "[nvim-cmp](https://github.com/hrsh7th/nvim-cmp) (triggered by typing `[[` for wiki links or "
      .. "just `[` for markdown links), powered by [`ripgrep`](https://github.com/BurntSushi/ripgrep)"
    assert.are_same({ { 1, 47, RefTypes.Markdown }, { 134, 183, RefTypes.Markdown } }, search.find_refs(s))
  end)
end)

describe("search.find_tags()", function()
  it("should find positions of all tags", function()
    local s = "I have a #meeting at noon"
    assert.are_same({ { 10, 17, RefTypes.Tag } }, search.find_tags(s))
  end)

  it("should ignore anchor links that look like tags", function()
    local s = "[readme](README#installation)"
    assert.are_same({}, search.find_tags(s))
  end)
end)

describe("search.find_and_replace_refs()", function()
  it("should find and replace all refs", function()
    local s, indices = search.find_and_replace_refs "[[Foo]] [[foo|Bar]]"
    local expected_s = "Foo Bar"
    local expected_indices = { { 1, 3 }, { 5, 7 } }
    assert.equals(s, expected_s)
    assert.equals(#indices, #expected_indices)
    for i = 1, #indices do
      assert.equals(indices[i][1], expected_indices[i][1])
      assert.equals(indices[i][2], expected_indices[i][2])
    end
  end)
end)

describe("search.replace_refs()", function()
  it("should remove refs and links from a string", function()
    assert.equals(search.replace_refs "Hi there [[foo|Bar]]", "Hi there Bar")
    assert.equals(search.replace_refs "Hi there [[Bar]]", "Hi there Bar")
    assert.equals(search.replace_refs "Hi there [Bar](foo)", "Hi there Bar")
    assert.equals(search.replace_refs "Hi there [[foo|Bar]] [[Baz]]", "Hi there Bar Baz")
  end)
end)

describe("search.SearchOpts", function()
  it("should initialize from a raw table and resolve to ripgrep options", function()
    local opts = SearchOpts.from_tbl {
      sort_by = "modified",
      fixed_strings = true,
      ignore_case = true,
      exclude = { "templates" },
      max_count_per_file = 1,
    }
    assert.are_same(
      opts:to_ripgrep_opts(),
      { "--sortr=modified", "--fixed-strings", "--ignore-case", "-g!templates", "-m=1" }
    )
  end)

  it("should not include any options with defaults", function()
    local opts = SearchOpts.from_tbl {}
    assert.are_same(opts:to_ripgrep_opts(), {})
  end)

  it("should initialize from another SearchOpts instance", function()
    local opts = SearchOpts.from_tbl(SearchOpts.from_tbl { fixed_strings = true })
    assert.are_same(opts:to_ripgrep_opts(), { "--fixed-strings" })
  end)

  it("should merge with another SearchOpts instance", function()
    local opts = SearchOpts.from_tbl { fixed_strings = true, max_count_per_file = 1 }
    opts = opts:merge { fixed_strings = false, ignore_case = true }
    assert.are_same(opts:to_ripgrep_opts(), { "--ignore-case", "-m=1" })
  end)
end)

describe("search.RefTypes", function()
  it("should have all keys matching values", function()
    for k, v in pairs(RefTypes) do
      assert(k == v)
    end
  end)
end)

describe("search.Patterns", function()
  it("should include a pattern for every RefType", function()
    for _, ref_type in pairs(RefTypes) do
      assert(type(Patterns[ref_type]) == "string")
    end
  end)
end)
