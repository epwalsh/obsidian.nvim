local Path = require "obsidian.path"

describe("Path.new", function()
  it("should initialize with both method syntax and regular dot access", function()
    ---@type obsidian.Path
    local path

    path = Path.new "README.md"
    assert.equal("README.md", path.filename)

    path = Path:new "README.md"
    assert.equal("README.md", path.filename)
  end)
end)
