local collections = require "obsidian.collections"

describe("DefaultTbl", function()
  it("should work with get", function()
    local t = collections.DefaultTbl.new(function()
      return {}
    end)

    local x = t["a"]
    x[#x + 1] = 1

    assert.are_same(t["a"], { 1 })
  end)

  it("should work with set", function()
    local t = collections.DefaultTbl.new(function()
      return {}
    end)

    t["a"][1] = 1
    assert.are_same(t["a"], { 1 })
  end)
end)
