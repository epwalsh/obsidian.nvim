local Line = require "obsidian.yaml.line"

describe("Line class", function()
  it("should strip spaces and count the indent", function()
    local line = Line.new "  foo: 1 "
    assert.equals(2, line.indent)
    assert.equals("foo: 1", line.content)
  end)

  it("should strip tabs and count the indent", function()
    local line = Line.new "		foo: 1"
    assert.equals(2, line.indent)
    assert.equals("foo: 1", line.content)
  end)
end)
