local ThreadPoolExecutor = require("obsidian.threading").ThreadPoolExecutor

describe("ThreadPoolExecutor.map()", function()
  it("should maintain order of results with a table of args", function()
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

  it("should maintain order of results with a generator of args", function()
    local executor = ThreadPoolExecutor.new()
    local task_args = { { 1 }, { 2 }, { 3 }, { 4 } }
    local i = 0
    local function task_args_gen()
      i = i + 1
      return task_args[i]
    end

    executor:map(function(id)
      local uv = vim.loop
      uv.sleep(100)
      return id
    end, function(results)
      assert.are_same(results, { { 1 }, { 2 }, { 3 }, { 4 } })
    end, task_args_gen)

    executor:join(500)
  end)
end)
