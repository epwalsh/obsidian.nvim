local util = require "obsidian.util"
local RefTypes = util.RefTypes

describe("util.get_open_strategy()", function()
  it("should return the correct open strategy", function()
    assert.equals(util.get_open_strategy "current", "e ")
    assert.equals(util.get_open_strategy "hsplit", "sp ")
    assert.equals(util.get_open_strategy "vsplit", "vsp ")
  end)
end)

describe("util.urlencode()", function()
  it("should correctly URL-encode a path", function()
    assert.equals(util.urlencode [[~/Library/Foo Bar.md]], [[~%2FLibrary%2FFoo%20Bar.md]])
  end)
end)

describe("util.match_case()", function()
  it("should match case of key to prefix", function()
    assert.equals(util.match_case("Foo", "foo"), "Foo")
    assert.equals(util.match_case("In-cont", "in-context learning"), "In-context learning")
  end)
end)

describe("util.replace_refs()", function()
  it("should remove refs and links from a string", function()
    assert.equals(util.replace_refs "Hi there [[foo|Bar]]", "Hi there Bar")
    assert.equals(util.replace_refs "Hi there [[Bar]]", "Hi there Bar")
    assert.equals(util.replace_refs "Hi there [Bar](foo)", "Hi there Bar")
    assert.equals(util.replace_refs "Hi there [[foo|Bar]] [[Baz]]", "Hi there Bar Baz")
  end)
end)

describe("util.find_refs()", function()
  it("should find positions of all refs", function()
    local s = "[[Foo]] [[foo|Bar]]"
    assert.are_same({ { 1, 7, RefTypes.Wiki }, { 9, 19, RefTypes.WikiWithAlias } }, util.find_refs(s))
  end)

  it("should ignore refs within an inline code block", function()
    local s = "`[[Foo]]` [[foo|Bar]]"
    assert.are_same({ { 11, 21, RefTypes.WikiWithAlias } }, util.find_refs(s))

    s = "[nvim-cmp](https://github.com/hrsh7th/nvim-cmp) (triggered by typing `[[` for wiki links or "
      .. "just `[` for markdown links), powered by [`ripgrep`](https://github.com/BurntSushi/ripgrep)"
    assert.are_same({ { 1, 47, RefTypes.Markdown }, { 134, 183, RefTypes.Markdown } }, util.find_refs(s))
  end)
end)

describe("util.find_and_replace_refs()", function()
  it("should find and replace all refs", function()
    local s, indices = util.find_and_replace_refs "[[Foo]] [[foo|Bar]]"
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

describe("util.table_params_to_str()", function()
  it("should convert a list of params into a string", function()
    local as_string = util.table_params_to_str { "find", "/home/user/obsidian", "-name", "*.md" }
    assert.equals(as_string, "find /home/user/obsidian -name *.md")
  end)
end)

describe("util.cursor_on_markdown_link()", function()
  it("should correctly find if coursor is on markdown/wiki link", function()
    --           0    5    10   15   20   25   30   35   40    45  50   55
    --           |    |    |    |    |    |    |    |    |    |    |    |
    local text = "The [other](link/file.md) plus [[yet|another/file.md]] there"
    local tests = {
      { cur_col = 4, open = nil, close = nil },
      { cur_col = 5, open = 5, close = 25 },
      { cur_col = 7, open = 5, close = 25 },
      { cur_col = 25, open = 5, close = 25 },
      { cur_col = 26, open = nil, close = nil },
      { cur_col = 31, open = nil, close = nil },
      { cur_col = 32, open = 32, close = 54 },
      { cur_col = 40, open = 32, close = 54 },
      { cur_col = 54, open = 32, close = 54 },
      { cur_col = 55, open = nil, close = nil },
    }
    for _, test in ipairs(tests) do
      local open, close = util.cursor_on_markdown_link(text, test.cur_col)
      assert.equals(test.open, open, "cursor at: " .. test.cur_col)
      assert.equals(test.close, close, "close")
    end
  end)
end)

describe("util.escape_magic_characters()", function()
  it("should correctly escape magic characters", function()
    -- special characters: ^$()%.[]*+-?
    assert.equals(util.escape_magic_characters "^foo", "%^foo")
    assert.equal(util.escape_magic_characters "foo$", "foo%$")
    assert.equal(util.escape_magic_characters "foo(bar)", "foo%(bar%)")
    assert.equal(util.escape_magic_characters "foo.bar", "foo%.bar")
    assert.equal(util.escape_magic_characters "foo[bar]", "foo%[bar%]")
    assert.equal(util.escape_magic_characters "foo*bar", "foo%*bar")
    assert.equal(util.escape_magic_characters "foo+bar", "foo%+bar")
    assert.equal(util.escape_magic_characters "foo-bar", "foo%-bar")
    assert.equal(util.escape_magic_characters "foo?bar", "foo%?bar")
    assert.equal(util.escape_magic_characters "foo%bar", "foo%%bar")
  end)
end)

describe("util.unescape_single_backslash()", function()
  it("should correctly remove single backslash", function()
    -- [[123\|NOTE1]] should get [[123|NOTE1]] in markdown file
    -- in lua, it needs to be with double backslash '\\'
    assert.equals(util.unescape_single_backslash "[[foo\\|bar]]", "[[foo|bar]]")
  end)
end)

describe("util.count_indent()", function()
  it("should count each space as one indent", function()
    assert.equals(2, util.count_indent "  ")
  end)

  it("should count each tab as one indent", function()
    assert.equals(2, util.count_indent "		")
  end)
end)

describe("util.is_whitespace()", function()
  it("should identify whitespace-only strings", function()
    assert.is_true(util.is_whitespace "  ")
    assert.is_false(util.is_whitespace "a  ")
  end)
end)

describe("util.next_item()", function()
  it("should pull out next list item with enclosing quotes", function()
    assert.equals('"foo"', util.next_item([=["foo", "bar"]=], { "," }))
  end)

  it("should pull out the last list item with enclosing quotes", function()
    assert.equals('"foo"', util.next_item([=["foo"]=], { "," }))
  end)

  it("should pull out the last list item with enclosing quotes and stop char", function()
    assert.equals('"foo"', util.next_item([=["foo",]=], { "," }))
  end)

  it("should pull out next list item without enclosing quotes", function()
    assert.equals("foo", util.next_item([=[foo, "bar"]=], { "," }))
  end)

  it("should pull out next list item even when the item contains the stop char", function()
    assert.equals('"foo, baz"', util.next_item([=["foo, baz", "bar"]=], { "," }))
  end)

  it("should pull out the last list item without enclosing quotes", function()
    assert.equals("foo", util.next_item([=[foo]=], { "," }))
  end)

  it("should pull out the last list item without enclosing quotes and stop char", function()
    assert.equals("foo", util.next_item([=[foo,]=], { "," }))
  end)

  it("should pull nested array", function()
    assert.equals("[foo, bar]", util.next_item("[foo, bar],", { "]" }, true))
  end)

  it("should pull out the key in an array", function()
    local next_item, str = util.next_item("foo: bar", { ":" }, false)
    assert.equals("foo", next_item)
    assert.equals(" bar", str)

    next_item, str = util.next_item("bar: 1, baz: 'Baz'", { ":" }, false)
    assert.equals("bar", next_item)
    assert.equals(" 1, baz: 'Baz'", str)
  end)
end)

describe("util.strip_whitespace()", function()
  it("should strip tabs and spaces from both ends", function()
    assert.equals("foo", util.strip_whitespace "	foo ")
  end)
end)

describe("util.lstrip_whitespace()", function()
  it("should strip tabs and spaces from left end only", function()
    assert.equals("foo ", util.lstrip_whitespace "	foo ")
  end)

  it("should respect the limit parameters", function()
    assert.equals(" foo ", util.lstrip_whitespace("  foo ", 1))
  end)
end)

describe("util.strip_comments()", function()
  it("should strip comments from a string", function()
    assert.equals("foo: 1", util.strip_comments "foo: 1  # this is a comment")
  end)

  it("should ignore '#' when enclosed in quotes", function()
    assert.equals([["hashtags start with '#'"]], util.strip_comments [["hashtags start with '#'"]])
  end)
end)

describe("util.string_replace()", function()
  it("replace all instances", function()
    assert.equals(
      "the link is [[bar|Foo]] or [[bar]], right?",
      util.string_replace("the link is [[foo|Foo]] or [[foo]], right?", "[[foo", "[[bar")
    )
  end)

  it("not replace more than requested", function()
    assert.equals(
      "the link is [[bar|Foo]] or [[foo]], right?",
      util.string_replace("the link is [[foo|Foo]] or [[foo]], right?", "[[foo", "[[bar", 1)
    )
  end)
end)

describe("util.enumerate()", function()
  local function collect(iterator)
    local results = {}
    for i, x in iterator do
      results[i] = x
    end
    return results
  end

  it("should enumerate over strings", function()
    assert.are_same({ "h", "e", "l", "l", "o" }, collect(util.enumerate "hello"))
  end)

  it("should enumerate over arrays", function()
    assert.are_same({ 1, 2, 3 }, collect(util.enumerate { 1, 2, 3 }))
  end)

  it("should enumerate over mapping keys", function()
    local results = {}
    for _, k in util.enumerate { a = 1, b = 2, c = 3 } do
      results[k] = true
    end
    assert.are_same({ a = true, b = true, c = true }, results)
  end)
end)
