local yaml = require "obsidian.yaml"

describe("obsidian.yaml.dumps", function()
  it("should dump numbers", function()
    assert.equals(yaml.dumps(1), "1")
  end)
  it("should dump strings", function()
    assert.equals(yaml.dumps "hi there", "hi there")
    assert.equals(yaml.dumps "hi it's me", "hi it's me")
    assert.equals(yaml.dumps { foo = "bar" }, [[foo: bar]])
  end)
  it("should dump strings with a single quote without quoting", function()
    assert.equals(yaml.dumps "hi it's me", "hi it's me")
  end)
  it("should dump table with string values", function()
    assert.equals(yaml.dumps { foo = "bar" }, [[foo: bar]])
  end)
  it("should dump arrays with string values", function()
    assert.equals(yaml.dumps { "foo", "bar" }, "- foo\n- bar")
  end)
  it("should dump arrays with number values", function()
    assert.equals(yaml.dumps { 1, 2 }, "- 1\n- 2")
  end)
  it("should dump arrays with simple table values", function()
    assert.equals(yaml.dumps { { a = 1 }, { b = 2 } }, "- a: 1\n- b: 2")
  end)
  it("should dump tables with string values", function()
    assert.equals(yaml.dumps { a = "foo", b = "bar" }, "a: foo\nb: bar")
  end)
  it("should dump tables with number values", function()
    assert.equals(yaml.dumps { a = 1, b = 2 }, "a: 1\nb: 2")
  end)
  it("should dump tables with array values", function()
    assert.equals(yaml.dumps { a = { "foo" }, b = { "bar" } }, "a:\n  - foo\nb:\n  - bar")
  end)
  it("should dump tables with empty array", function()
    assert.equals(yaml.dumps { a = {} }, "a: []")
  end)
  it("should quote empty strings or strings with just whitespace", function()
    assert.equals(yaml.dumps { a = "" }, 'a: ""')
    assert.equals(yaml.dumps { a = " " }, 'a: " "')
  end)
  it("should not quote date-like strings", function()
    assert.equals(yaml.dumps { a = "2023_11_10 13:26" }, "a: 2023_11_10 13:26")
  end)
  it("should otherwise quote strings with a colon followed by whitespace", function()
    assert.equals(yaml.dumps { a = "2023: a letter" }, [[a: "2023: a letter"]])
  end)
  it("should quote strings that start with special characters", function()
    assert.equals(yaml.dumps { a = "& aaa" }, [[a: "& aaa"]])
    assert.equals(yaml.dumps { a = "! aaa" }, [[a: "! aaa"]])
    assert.equals(yaml.dumps { a = "- aaa" }, [[a: "- aaa"]])
    assert.equals(yaml.dumps { a = "{ aaa" }, [[a: "{ aaa"]])
    assert.equals(yaml.dumps { a = "[ aaa" }, [[a: "[ aaa"]])
    assert.equals(yaml.dumps { a = "'aaa'" }, [[a: "'aaa'"]])
    assert.equals(yaml.dumps { a = '"aaa"' }, [[a: "\"aaa\""]])
  end)
  it("should not unnecessarily escape double quotes in strings", function()
    assert.equals(yaml.dumps { a = 'his name is "Winny the Poo"' }, 'a: his name is "Winny the Poo"')
  end)
end)

describe("obsidian.yaml.native", function()
  yaml.set_parser "native"
  it("should parse inline lists with quotes on items", function()
    local data = yaml.loads 'aliases: ["Foo", "Bar", "Foo Baz"]'
    assert.equals(type(data), "table")
    assert.equals(type(data.aliases), "table")
    assert.equals(#data.aliases, 3)
    assert.equals(data.aliases[3], "Foo Baz")

    data = yaml.loads 'aliases: ["Foo"]'
    assert.equals(type(data), "table")
    assert.equals(type(data.aliases), "table")
    assert.equals(#data.aliases, 1)
    assert.equals(data.aliases[1], "Foo")

    data = yaml.loads 'aliases: ["Foo Baz"]'
    assert.equals(type(data), "table")
    assert.equals(type(data.aliases), "table")
    assert.equals(#data.aliases, 1)
    assert.equals(data.aliases[1], "Foo Baz")
  end)
  it("should parse inline lists without quotes on items", function()
    local data = yaml.loads "aliases: [Foo, Bar, Foo Baz]"
    assert.equals(type(data), "table")
    assert.equals(type(data.aliases), "table")
    assert.equals(#data.aliases, 3)
    assert.equals(data.aliases[3], "Foo Baz")

    data = yaml.loads "aliases: [Foo]"
    assert.equals(type(data), "table")
    assert.equals(type(data.aliases), "table")
    assert.equals(#data.aliases, 1)
    assert.equals(data.aliases[1], "Foo")

    data = yaml.loads "aliases: [Foo Baz]"
    assert.equals(type(data), "table")
    assert.equals(type(data.aliases), "table")
    assert.equals(#data.aliases, 1)
    assert.equals(data.aliases[1], "Foo Baz")
  end)
  it("should parse boolean field values", function()
    local data = yaml.loads "complete: false"
    assert.equals(type(data), "table")
    assert.equals(type(data.complete), "boolean")
  end)
  it("should parse implicit null values", function()
    local data = yaml.loads "tags: \ncomplete: false"
    assert.equals(type(data), "table")
    assert.equals(data.tags, nil)
    assert.equals(data.complete, false)
  end)
end)

describe("obsidian.yaml.yq", function()
  yaml.set_parser "yq"
  for key, data in pairs {
    ["numbers"] = 1,
    ["strings"] = "hi there",
    ["strings with single quotes"] = "hi it's me",
    ["tables with string values"] = { foo = "bar" },
    ["arrays with string values"] = { "foo", "bar" },
    ["arrays with number values"] = { 1, 2 },
    ["arrays with table values"] = { { a = 1 }, { b = 2 } },
    ["tables with number values"] = { a = 1 },
    ["tables with an empty array"] = { a = {} },
  } do
    it("should dump/parse " .. key, function()
      assert.are.same(yaml.loads(yaml.dumps(data)), data)
    end)
  end
  it("should parse inline lists with quotes on items", function()
    local data = yaml.loads 'aliases: ["Foo", "Bar", "Foo Baz"]'
    assert.equals(type(data), "table")
    assert.equals(type(data.aliases), "table")
    assert.equals(#data.aliases, 3)
    assert.equals(data.aliases[3], "Foo Baz")

    data = yaml.loads 'aliases: ["Foo"]'
    assert.equals(type(data), "table")
    assert.equals(type(data.aliases), "table")
    assert.equals(#data.aliases, 1)
    assert.equals(data.aliases[1], "Foo")

    data = yaml.loads 'aliases: ["Foo Baz"]'
    assert.equals(type(data), "table")
    assert.equals(type(data.aliases), "table")
    assert.equals(#data.aliases, 1)
    assert.equals(data.aliases[1], "Foo Baz")
  end)
  it("should parse inline lists without quotes on items", function()
    local data = yaml.loads "aliases: [Foo, Bar, Foo Baz]"
    assert.equals(type(data), "table")
    assert.equals(type(data.aliases), "table")
    assert.equals(#data.aliases, 3)
    assert.equals(data.aliases[3], "Foo Baz")

    data = yaml.loads "aliases: [Foo]"
    assert.equals(type(data), "table")
    assert.equals(type(data.aliases), "table")
    assert.equals(#data.aliases, 1)
    assert.equals(data.aliases[1], "Foo")

    data = yaml.loads "aliases: [Foo Baz]"
    assert.equals(type(data), "table")
    assert.equals(type(data.aliases), "table")
    assert.equals(#data.aliases, 1)
    assert.equals(data.aliases[1], "Foo Baz")
  end)
  it("should parse boolean field values", function()
    local data = yaml.loads "complete: false"
    assert.equals(type(data), "table")
    assert.equals(type(data.complete), "boolean")
  end)
  it("should parse implicit null values", function()
    local data = yaml.loads "tags: \ncomplete: false"
    assert.equals(type(data), "table")
    assert.equals(data.tags, nil)
    assert.equals(data.complete, false)
  end)
end)
