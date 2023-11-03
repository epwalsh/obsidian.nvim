local ThreadPoolExecutor = require("obsidian.threading").ThreadPoolExecutor

describe("ThreadPoolExecutor.map()", function()
  it("should maintain order of results", function()
    local executor = ThreadPoolExecutor.new()
    local task_args = { { 1 }, { 2 }, { 3 }, { 4 } }

    executor:map(function(id)
      local uv = vim.loop
      uv.sleep(100)
      return id
    end, function(results)
      assert.are_same(results, { { 1 }, { 2 }, { 3 }, { 4 } })
    end, task_args)

    executor:join(500)
  end)
end)
