local AsyncExecutor = require("obsidian.async").AsyncExecutor
local ThreadPoolExecutor = require("obsidian.async").ThreadPoolExecutor
local File = require("obsidian.async").File
local a = require "plenary.async"
local with = require("plenary.context_manager").with
local open = require("plenary.context_manager").open

describe("AsyncExecutor.map()", function()
  it("should maintain order of results with a table of args", function()
    local executor = AsyncExecutor.new()
    local task_args = { { 1 }, { 2 }, { 3 }, { 4 } }

    executor:map(
      function(id)
        local uv = vim.loop
        uv.sleep(100)
        return id
      end,
      task_args,
      function(results)
        assert.are_same(results, { { 1 }, { 2 }, { 3 }, { 4 } })
      end
    )

    executor:join(500)
  end)

  it("should maintain order of results with a generator of args", function()
    local executor = AsyncExecutor.new()
    local task_args = { 1, 2, 3, 4 }
    local i = 0
    local function task_args_gen()
      i = i + 1
      return task_args[i]
    end

    executor:map(
      function(id)
        local uv = vim.loop
        uv.sleep(100)
        return id
      end,
      task_args_gen,
      function(results)
        assert.are_same(results, { { 1 }, { 2 }, { 3 }, { 4 } })
      end
    )

    executor:join(500)
  end)
end)

describe("ThreadPoolExecutor.map()", function()
  it("should maintain order of results with a table of args", function()
    local executor = ThreadPoolExecutor.new()
    local task_args = { { 1 }, { 2 }, { 3 }, { 4 } }

    executor:map(
      function(id)
        local uv = vim.loop
        uv.sleep(100)
        return id
      end,
      task_args,
      function(results)
        assert.are_same(results, { { 1 }, { 2 }, { 3 }, { 4 } })
      end
    )

    executor:join(500)
  end)

  it("should maintain order of results with a generator of args", function()
    local executor = ThreadPoolExecutor.new()
    local task_args = { 1, 2, 3, 4 }
    local i = 0
    local function task_args_gen()
      i = i + 1
      return task_args[i]
    end

    executor:map(
      function(id)
        local uv = vim.loop
        uv.sleep(100)
        return id
      end,
      task_args_gen,
      function(results)
        assert.are_same(results, { { 1 }, { 2 }, { 3 }, { 4 } })
      end
    )

    executor:join(500)
  end)
end)

describe("File.lines()", function()
  it("should correctly read all lines from a file", function()
    local path = ".github/RELEASE_PROCESS.md"
    local actual_lines = {}
    with(open(path), function(reader)
      for line in reader:lines() do
        actual_lines[#actual_lines + 1] = line
      end
    end)

    local lines = {}
    a.util.block_on(function()
      ---@diagnostic disable-next-line: redefined-local
      local f = File.open(path)
      for line in f:lines(false) do
        lines[#lines + 1] = line
      end
      f:close()
    end, 1000)

    assert.are_same(lines, actual_lines)
  end)
end)
