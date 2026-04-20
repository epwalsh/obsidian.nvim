local yaml = require "obsidian.yaml.parser"
local util = require "obsidian.util"

describe("Parser class", function()
  local parser = yaml.new { luanil = false }

  it("should parse strings while trimming whitespace", function()
    assert.equals("foo", parser:parse_string " foo")
  end)

  it("should parse strings enclosed with double quotes", function()
    assert.equals("foo", parser:parse_string [["foo"]])
  end)

  it("should parse strings enclosed with single quotes", function()
    assert.equals("foo", parser:parse_string [['foo']])
  end)

  it("should parse strings with escaped quotes", function()
    assert.equals([["foo"]], parser:parse_string [["\"foo\""]])
  end)

  it("should parse numbers while trimming whitespace", function()
    assert.equals(1, parser:parse_number " 1")
    assert.equals(1.5, parser:parse_number " 1.5")
  end)

  it("should error when trying to parse an invalid number", function()
    local ok, _ = pcall(function(str)
      return parser:parse_number(str)
    end, "foo")
    assert.is_false(ok)
    ok, _ = pcall(function(str)
      return parser:parse_number(str)
    end, "Nan")
    assert.is_false(ok)
  end)

  it("should parse booleans while trimming whitespace", function()
    assert.is_true(parser:parse_boolean " true")
    assert.is_false(parser:parse_boolean " false ")
  end)

  it("should error when trying to parse an invalid boolean", function()
    local ok, _ = pcall(function(str)
      return parser:parse_boolean(str)
    end, "foo")
    assert.is_false(ok)
  end)

  it("should parse explicit null values while trimming whitespace", function()
    assert.are_same(vim.NIL, parser:parse_null " null")
  end)

  it("should parse implicit null values", function()
    assert.are_same(vim.NIL, parser:parse_null " ")
  end)

  it("should error when trying to parse an invalid null value", function()
    local ok, _ = pcall(function(str)
      return parser:parse_null(str)
    end, "foo")
    assert.is_false(ok)
  end)

  it("should error when for invalid indentation", function()
    local ok, err = pcall(function(str)
      return parser:parse(str)
    end, " foo: 1\nbar: 2")
    assert.is_false(ok)
    assert(util.string_contains(err, "indentation"), err)
  end)

  it("should parse root-level scalars", function()
    assert.are_same("a string", parser:parse "a string")
    assert.are_same(true, parser:parse "true")
  end)

  it("should parse simple non-nested mappings", function()
    local result = parser:parse(table.concat({
      "foo: 1",
      "",
      "bar: 2",
      "baz: blah",
      "some_bool: true",
      "some_implicit_null:",
      "some_explicit_null: null",
    }, "\n"))
    assert.are_same({
      foo = 1,
      bar = 2,
      baz = "blah",
      some_bool = true,
      some_explicit_null = vim.NIL,
      some_implicit_null = vim.NIL,
    }, result)
  end)

  it("should parse mappings with spaces for keys", function()
    local result = parser:parse(table.concat({
      "bar: 2",
      "modification date: Tuesday 26th March 2024 18:01:42",
    }, "\n"))
    assert.are_same({
      bar = 2,
      ["modification date"] = "Tuesday 26th March 2024 18:01:42",
    }, result)
  end)

  it("should ignore comments", function()
    local result = parser:parse(table.concat({
      "foo: 1  # this is a comment",
      "# comment on a whole line",
      "bar: 2",
      "baz: blah  # another comment",
      "some_bool: true",
      "some_implicit_null: # and another",
      "some_explicit_null: null",
    }, "\n"))
    assert.are_same({
      foo = 1,
      bar = 2,
      baz = "blah",
      some_bool = true,
      some_explicit_null = vim.NIL,
      some_implicit_null = vim.NIL,
    }, result)
  end)

  it("should parse lists with or without extra indentation", function()
    local result = parser:parse(table.concat({
      "foo:",
      "- 1",
      "- 2",
      "bar:",
      " - 3",
      " # ignore this comment",
      " - 4",
    }, "\n"))
    assert.are_same({
      foo = { 1, 2 },
      bar = { 3, 4 },
    }, result)
  end)

  it("should parse a top-level list", function()
    local result = parser:parse(table.concat({
      "- 1",
      "- 2",
      "# ignore this comment",
      "- 3",
    }, "\n"))
    assert.are_same({ 1, 2, 3 }, result)
  end)

  it("should parse nested mapping", function()
    local result = parser:parse(table.concat({
      "foo:",
      "  bar: 1",
      "  # ignore this comment",
      "  baz: 2",
    }, "\n"))
    assert.are_same({ foo = { bar = 1, baz = 2 } }, result)
  end)

  it("should parse block strings", function()
    local result = parser:parse(table.concat({
      "foo: |",
      "  # a comment here should not be ignored!",
      "  ls -lh",
      "    # extra indent should not be ignored either!",
    }, "\n"))
    assert.are_same({
      foo = table.concat(
        { "# a comment here should not be ignored!", "ls -lh", "  # extra indent should not be ignored either!" },
        "\n"
      ),
    }, result)
  end)

  it("should parse multi-line strings", function()
    local result = parser:parse(table.concat({
      "foo: 'this is the start of a string'",
      "  # a comment here should not be ignored!",
      "  'and this is the end of it'",
      "bar: 1",
    }, "\n"))
    assert.are_same({
      foo = table.concat({ "this is the start of a string and this is the end of it" }, "\n"),
      bar = 1,
    }, result)
  end)

  it("should parse inline arrays", function()
    local result = parser:parse(table.concat({
      "foo: [Foo, 'Bar', 1]",
    }, "\n"))
    assert.are_same({ foo = { "Foo", "Bar", 1 } }, result)
  end)

  it("should parse nested inline arrays", function()
    local result = parser:parse(table.concat({
      "foo: [Foo, ['Bar', 'Baz'], 1]",
    }, "\n"))
    assert.are_same({ foo = { "Foo", { "Bar", "Baz" }, 1 } }, result)
  end)

  it("should parse inline mappings", function()
    local result = parser:parse(table.concat({
      "foo: {bar: 1, baz: 'Baz'}",
    }, "\n"))
    assert.are_same({ foo = { bar = 1, baz = "Baz" } }, result)
  end)

  it("should parse array item strings with ':' in them", function()
    local result = parser:parse(table.concat({
      "aliases:",
      ' - "Research project: staged training"',
      "sources:",
      " - https://example.com",
    }, "\n"))
    assert.are_same({ aliases = { "Research project: staged training" }, sources = { "https://example.com" } }, result)
  end)

  it("should parse array item strings with '#' in them", function()
    local result = parser:parse(table.concat({
      "tags:",
      " - #demo",
    }, "\n"))
    assert.are_same({ tags = { "#demo" } }, result)
  end)

  it("should parse array item strings that look like markdown links", function()
    local result = parser:parse(table.concat({
      "links:",
      " - [Foo](bar)",
    }, "\n"))
    assert.are_same({ links = { "[Foo](bar)" } }, result)
  end)
end)
