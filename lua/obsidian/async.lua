local async = require "plenary.async"
local channel = require("plenary.async.control").channel
local uv = vim.loop

local M = {}

---An abstract class that mimics Python's `concurrent.futures.Executor` class.
---@class obsidian.Executor
---@field tasks_running integer
local Executor = {}

---@return obsidian.Executor
Executor.new = function()
  local self = setmetatable({}, { __index = Executor })
  self.tasks_running = 0
  return self
end

---Submit a one-off function with a callback to the thread pool.
---
---@param self obsidian.Executor
---@param fn function
---@param callback function|?
---@diagnostic disable-next-line: unused-local,unused-vararg
Executor.submit = function(self, fn, callback, ...)
  error "not implemented"
end

---Map a function over a generator or array of task args. The callback is called with an array of the results
---once all tasks have finished. The order of the results passed to the callback will be the same
---as the order of the corresponding task args.
---
---@param self obsidian.Executor
---@param fn function
---@param callback function|?
---@param task_args table[]|function
---@diagnostic disable-next-line: unused-local
Executor.map = function(self, fn, callback, task_args)
  local results = {}
  local num_tasks = 0
  local tasks_completed = 0
  local all_submitted = false
  local tx, rx = channel.oneshot()

  local function collect_results()
    rx()
    return results
  end

  local function get_task_done_fn(i)
    return function(...)
      tasks_completed = tasks_completed + 1
      results[i] = { ... }
      if all_submitted and tasks_completed == num_tasks then
        tx()
      end
    end
  end

  if type(task_args) == "table" then
    num_tasks = #task_args

    for i, args in ipairs(task_args) do
      self:submit(fn, get_task_done_fn(i), unpack(args))
    end
  elseif type(task_args) == "function" then
    local i = 0
    local args = { task_args() }
    local next_args = { task_args() }
    while args[1] ~= nil do
      if next_args[1] == nil then
        all_submitted = true
      end
      if args[1] ~= nil then
        i = i + 1
        num_tasks = num_tasks + 1
        self:submit(fn, get_task_done_fn(i), unpack(args))
      end
      args = next_args
      next_args = { task_args() }
    end
  end

  if num_tasks == 0 then
    if callback ~= nil then
      callback {}
    end
  else
    async.run(collect_results, callback and callback or function(_) end)
  end
end

---Block Neovim until all currently running tasks have completed, waiting at most `timeout` milliseconds
---before raising a timeout error.
---
---This is useful in testing, but in general you want to avoid blocking Neovim.
---
---@param self obsidian.Executor
---@param timeout integer|?
Executor.join = function(self, timeout)
  local start_time = uv.uptime()
  local pause_for = 100
  if timeout ~= nil then
    pause_for = math.min(timeout / 2, pause_for)
  end
  while self.tasks_running > 0 do
    vim.wait(pause_for)
    if timeout ~= nil and uv.uptime() - start_time > timeout then
      error "Timeout error from AsyncExecutor.join()"
    end
  end
end

---An Executor that uses coroutines to run user functions concurrently.
---@class obsidian.AsyncExecutor : obsidian.Executor
---@field tasks_running integer
local AsyncExecutor = Executor.new()
M.AsyncExecutor = AsyncExecutor

---@return obsidian.AsyncExecutor
AsyncExecutor.new = function()
  local self = setmetatable({}, { __index = AsyncExecutor })
  self.tasks_running = 0
  return self
end

---Submit a one-off function with a callback to the thread pool.
---
---@param self obsidian.AsyncExecutor
---@param fn function
---@param callback function|?
---@diagnostic disable-next-line: unused-local
AsyncExecutor.submit = function(self, fn, callback, ...)
  self.tasks_running = self.tasks_running + 1
  local args = { ... }
  async.run(function()
    return fn(unpack(args))
  end, function(...)
    self.tasks_running = self.tasks_running - 1
    if callback ~= nil then
      callback(...)
    end
  end)
end

---A multi-threaded Executor which uses the Libuv threadpool.
---@class obsidian.ThreadPoolExecutor : obsidian.Executor
---@field tasks_running integer
local ThreadPoolExecutor = Executor.new()
M.ThreadPoolExecutor = ThreadPoolExecutor

---@return obsidian.ThreadPoolExecutor
ThreadPoolExecutor.new = function()
  local self = setmetatable({}, { __index = ThreadPoolExecutor })
  self.tasks_running = 0
  return self
end

---Submit a one-off function with a callback to the thread pool.
---
---@param self obsidian.ThreadPoolExecutor
---@param fn function
---@param callback function|?
---@diagnostic disable-next-line: unused-local
ThreadPoolExecutor.submit = function(self, fn, callback, ...)
  self.tasks_running = self.tasks_running + 1
  local ctx = uv.new_work(fn, function(...)
    self.tasks_running = self.tasks_running - 1
    if callback ~= nil then
      callback(...)
    end
  end)
  ctx:queue(...)
end

---Represents a file.
---@class obsidian.File
---@field fd userdata
local File = {}
M.File = File

---@param path string
---@return obsidian.File
File.open = function(path)
  local self = setmetatable({}, { __index = File })
  local err, fd = async.uv.fs_open(path, "r", 438)
  assert(not err, err)
  self.fd = fd
  return self
end

---Close the file.
---@param self obsidian.File
File.close = function(self)
  local err = async.uv.fs_close(self.fd)
  assert(not err, err)
end

---Get at iterator over lines in the file.
File.lines = function(self)
  local offset = 0
  local chunk_size = 1024
  local buffer = ""
  local eof_reached = false

  local lines = function()
    local idx = string.find(buffer, "[\r\n]")
    while idx == nil and not eof_reached do
      ---@diagnostic disable-next-line: redefined-local
      local err, data
      err, data = async.uv.fs_read(self.fd, chunk_size, offset)
      assert(not err, err)
      if string.len(data) == 0 then
        eof_reached = true
      else
        buffer = buffer .. data
        offset = offset + string.len(data)
        idx = string.find(buffer, "[\r\n]")
      end
    end

    if idx ~= nil then
      local line = string.sub(buffer, 1, idx)
      buffer = string.sub(buffer, idx + 1)
      return line
    else
      return nil
    end
  end

  return lines
end

return M
