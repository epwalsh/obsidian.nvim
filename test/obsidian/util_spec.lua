local util = require "obsidian.util"

describe("obsidian.util", function()
  it("should return the correct open strategy", function()
    assert.equals(util.get_open_strategy "current", "e ")
    assert.equals(util.get_open_strategy "hsplit", "sp ")
    assert.equals(util.get_open_strategy "vsplit", "vsp ")
  end)
  it("should correctly URL-encode a path", function()
    assert.equals(util.urlencode [[~/Library/Foo Bar.md]], [[~%2FLibrary%2FFoo%20Bar.md]])
  end)
  it("should match case of key to prefix", function()
    assert.equals(util.match_case("Foo", "foo"), "Foo")
    assert.equals(util.match_case("In-cont", "in-context learning"), "In-context learning")
  end)
  it("should remove refs and links from a string", function()
    assert.equals(util.replace_refs "Hi there [[foo|Bar]]", "Hi there Bar")
    assert.equals(util.replace_refs "Hi there [[Bar]]", "Hi there Bar")
    assert.equals(util.replace_refs "Hi there [Bar](foo)", "Hi there Bar")
    assert.equals(util.replace_refs "Hi there [[foo|Bar]] [[Baz]]", "Hi there Bar Baz")
  end)
  it("should find positions of all refs", function()
    local s = "[[Foo]] [[foo|Bar]]"
    local matches = util.find_refs(s)
    local expected = { { 1, 7 }, { 9, 19 } }
    assert.equals(#matches, #expected)
    for i, match in ipairs(matches) do
      assert.equals(match[1], expected[i][1])
      assert.equals(match[2], expected[i][2])
    end
  end)
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
  it("should convert a list of params into a string", function()
    local as_string = util.table_params_to_str { "find", "/home/user/obsidian", "-name", "*.md" }
    assert.equals(as_string, "find /home/user/obsidian -name *.md")
  end)
  it("should recursively find notes in a directory given a file name", function()
    local matches = util.find_note(".", "foo.md")
    assert.equals(#matches, 1)
    assert.equals(tostring(matches[1]), "./test_fixtures/notes/foo.md")
  end)
  it("should recursively find notes in a directory given a partial path", function()
    local matches = util.find_note(".", "notes/foo.md")
    assert.equals(#matches, 1)
    assert.equals(tostring(matches[1]), "./test_fixtures/notes/foo.md")
  end)
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
