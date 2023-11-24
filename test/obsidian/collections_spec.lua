local collections = require "obsidian.collections"

describe("DefaultTbl", function()
  local DefaultTbl = collections.DefaultTbl

  it("should work with get", function()
    local t = DefaultTbl.with_tbl()

    local x = t["a"]
    x[#x + 1] = 1

    assert.are_same(t["a"], { 1 })
  end)

  it("should work with set", function()
    local t = DefaultTbl.with_tbl()

    t["a"][1] = 1
    assert.are_same(t["a"], { 1 })
  end)

  it("should work with nested DefaultTbls", function()
    local t = DefaultTbl.new(DefaultTbl.with_tbl)

    t["a"]["b"][1] = 1
    assert.are_same(t["a"]["b"], { 1 })
  end)
end)

-- describe("OrderedTbl", function()
--   local OrderedTbl = collections.OrderedTbl

--   it("should get and set values like a regular table", function()
--     local t = OrderedTbl.new()

--     t["a"] = 1
--     assert.are_same(t["a"], 1)
--   end)

--   it("should maintain order with pairs()", function()
--     local t = OrderedTbl.new()

--     t["a"] = 1
--     t["b"] = 2
--     t["c"] = 3
--     t["d"] = 4

--     local key_values = {}
--     for k, v in pairs(t) do
--       key_values[#key_values + 1] = { k, v }
--     end

--     assert.are_same({ { "a", 1 }, { "b", 2 }, { "c", 3 }, { "d", 4 } }, key_values)
--   end)
-- end)
