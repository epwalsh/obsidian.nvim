local enumerate = require("obsidian.itertools").enumerate

describe("itertools.enumerate()", function()
  local function collect(iterator)
    local results = {}
    for i, x in iterator do
      results[i] = x
    end
    return results
  end

  it("should enumerate over strings", function()
    assert.are_same({ "h", "e", "l", "l", "o" }, collect(enumerate "hello"))
  end)

  it("should enumerate over arrays", function()
    assert.are_same({ 1, 2, 3 }, collect(enumerate { 1, 2, 3 }))
  end)

  it("should enumerate over mapping keys", function()
    local results = {}
    for _, k in enumerate { a = 1, b = 2, c = 3 } do
      results[k] = true
    end
    assert.are_same({ a = true, b = true, c = true }, results)
  end)
end)
