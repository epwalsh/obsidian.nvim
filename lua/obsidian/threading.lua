local async = require "plenary.async"
local channel = require("plenary.async.control").channel
local uv = vim.loop

local M = {}

---Mimics Python's ThreadPoolExecutor to harness the Libuv threadpool for running user code.
---@class obsidian.ThreadPoolExecutor
---@field tasks_running integer
local ThreadPoolExecutor = {}
M.ThreadPoolExecutor = ThreadPoolExecutor

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

---Map a function over a generator or array of task args. The callback is called with an array of the results
---once all tasks have finished. The order of the results passed to the callback will be the same
---as the order of the corresponding task args.
---
---@param self obsidian.ThreadPoolExecutor
---@param fn function
---@param callback function|?
---@param task_args table[]|function
---@diagnostic disable-next-line: unused-local
ThreadPoolExecutor.map = function(self, fn, callback, task_args)
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
    local args = task_args()
    while args ~= nil do
      i = i + 1
      num_tasks = num_tasks + 1
      self:submit(fn, get_task_done_fn(i), unpack(args))
      args = task_args()
    end
    all_submitted = true
  end

  async.run(collect_results, callback and callback or function(_) end)
end

---Block Neovim until all currently running tasks have completed, waiting at most `timeout` milliseconds
---before raising a timeout error.
---
---This is useful in testing, but in general you want to avoid blocking Neovim.
---
---@param self obsidian.ThreadPoolExecutor
---@param timeout integer|?
ThreadPoolExecutor.join = function(self, timeout)
  local start_time = uv.uptime()
  local pause_for = 100
  if timeout ~= nil then
    pause_for = math.min(timeout / 2, pause_for)
  end
  while self.tasks_running > 0 do
    vim.wait(pause_for)
    if timeout ~= nil and uv.uptime() - start_time > timeout then
      error "Timeout error from ThreadPoolExecutor.join()"
    end
  end
end

return M
