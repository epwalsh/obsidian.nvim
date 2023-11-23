local collections = require "obsidian.collections"

describe("DefaultTbl", function()
  it("should work with get", function()
    local t = collections.DefaultTbl.with_tbl()

    local x = t["a"]
    x[#x + 1] = 1

    assert.are_same(t["a"], { 1 })
  end)

  it("should work with set", function()
    local t = collections.DefaultTbl.with_tbl()

    t["a"][1] = 1
    assert.are_same(t["a"], { 1 })
  end)

  it("should work with nested DefaultTbls", function()
    local t = collections.DefaultTbl.new(collections.DefaultTbl.with_tbl)

    t["a"]["b"][1] = 1
    assert.are_same(t["a"]["b"], { 1 })
  end)
end)
