local util = require "obsidian.util"

describe("obsidian.util", function()
  it("should correctly URL-encode a path", function()
    assert.equals(util.urlencode [[~/Library/Foo Bar.md]], [[~%2FLibrary%2FFoo+Bar.md]])
  end)
end)
