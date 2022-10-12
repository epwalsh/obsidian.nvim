local util = require "obsidian.util"

describe("obsidian.util", function()
  it("should correctly URL-encode a path", function()
    assert.equals(util.urlencode [[~/Library/Foo Bar.md]], [[~%2FLibrary%2FFoo+Bar.md]])
  end)
  it("should match case of key to prefix", function()
    assert.equals(util.match_case("Foo", "foo"), "Foo")
    assert.equals(util.match_case("In-cont", "in-context learning"), "In-context learning")
  end)
end)
