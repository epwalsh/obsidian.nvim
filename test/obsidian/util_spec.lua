local util = require "obsidian.util"

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
