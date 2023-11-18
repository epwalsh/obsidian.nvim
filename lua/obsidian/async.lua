local Job = require "plenary.job"
local async = require "plenary.async"
local channel = require("plenary.async.control").channel
local echo = require "obsidian.echo"
local util = require "obsidian.util"
local iter = util.iter
local uv = vim.loop

local M = {}

---An abstract class that mimics Python's `concurrent.futures.Executor` class.
---@class obsidian.Executor
---@field tasks_running integer
---@field tasks_pending integer
local Executor = {}

---@return obsidian.Executor
Executor.new = function()
  local self = setmetatable({}, { __index = Executor })
  self.tasks_running = 0
  self.tasks_pending = 0
  return self
end

---Submit a one-off function with a callback for the executor to run.
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
---@param task_args table[]|function
---@param callback function|?
---@diagnostic disable-next-line: unused-local
Executor.map = function(self, fn, task_args, callback)
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
      i = i + 1
      num_tasks = num_tasks + 1
      self:submit(fn, get_task_done_fn(i), unpack(args))
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

---@param self obsidian.Executor
---@param timeout integer|?
---@param pause_fn function(integer)
Executor._join = function(self, timeout, pause_fn)
  ---@diagnostic disable-next-line: undefined-field
  local start_time = uv.hrtime() / 1000000 -- ns -> ms
  local pause_for = 100
  if timeout ~= nil then
    pause_for = math.min(timeout / 2, pause_for)
  end
  while self.tasks_pending > 0 or self.tasks_running > 0 do
    pause_fn(pause_for)
    ---@diagnostic disable-next-line: undefined-field
    if timeout ~= nil and (uv.hrtime() / 1000000) - start_time > timeout then
      return echo.fail "Timeout error from Executor.join()"
    end
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
  self:_join(timeout, vim.wait)
end

---An async version of `.join()`.
---
---@param self obsidian.Executor
---@param timeout integer|?
Executor.join_async = function(self, timeout)
  self:_join(timeout, async.util.sleep)
end

---Run the callback when the executor finishes all tasks.
---@param self obsidian.Executor
---@param timeout integer|?
---@param callback function
Executor.join_and_then = function(self, timeout, callback)
  async.run(function()
    self:join_async(timeout)
  end, callback)
end

---An Executor that uses coroutines to run user functions concurrently.
---@class obsidian.AsyncExecutor : obsidian.Executor
---@field max_workers integer|?
---@field tasks_running integer
---@field tasks_pending integer
local AsyncExecutor = Executor.new()
M.AsyncExecutor = AsyncExecutor

---@param max_workers integer|?
---@return obsidian.AsyncExecutor
AsyncExecutor.new = function(max_workers)
  local self = setmetatable({}, { __index = AsyncExecutor })
  if max_workers == nil then
    max_workers = 10
  elseif max_workers < 0 then
    max_workers = nil
  elseif max_workers == 0 then
    max_workers = 1
  end
  self.max_workers = max_workers
  self.tasks_running = 0
  self.tasks_pending = 0
  return self
end

---Submit a one-off function with a callback to the thread pool.
---
---@param self obsidian.AsyncExecutor
---@param fn function
---@param callback function|?
---@diagnostic disable-next-line: unused-local
AsyncExecutor.submit = function(self, fn, callback, ...)
  self.tasks_pending = self.tasks_pending + 1
  local args = { ... }
  async.run(function()
    if self.max_workers ~= nil then
      while self.tasks_running >= self.max_workers do
        async.util.sleep(20)
      end
    end
    self.tasks_pending = self.tasks_pending - 1
    self.tasks_running = self.tasks_running + 1
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
  self.tasks_pending = 0
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
  ---@diagnostic disable-next-line: undefined-field
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
---@param mode string|?
---@return obsidian.File
File.open = function(path, mode)
  local self = setmetatable({}, { __index = File })
  local err, fd = async.uv.fs_open(path, mode and mode or "r", 438)
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
---@param include_new_line_char boolean|?
File.lines = function(self, include_new_line_char)
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
      if include_new_line_char then
        return line
      else
        return string.sub(line, 1, -2)
      end
    else
      return nil
    end
  end

  return lines
end

---Write all lines to the file.
---@param lines string[]|function
File.write_lines = function(self, lines)
  for line in iter(lines) do
    if not string.find(line, "[\r\n]") then
      line = line .. "\n"
    end
    async.uv.fs_write(self.fd, line)
  end
end

---@param cmd string
---@param args string[]
---@param on_stdout function|? (string) -> nil
---@param on_exit function|? (integer) -> nil
---@return Job
local init_job = function(cmd, args, on_stdout, on_exit)
  local stderr_lines = {}

  return Job:new { ---@diagnostic disable-line: missing-fields
    command = cmd,
    args = args,
    on_stdout = function(err, line)
      if err ~= nil then
        return echo.err("Error running command '" .. cmd "' with arguments " .. vim.inspect(args) .. "\n:" .. err)
      end
      if on_stdout ~= nil then
        on_stdout(line)
      end
    end,
    on_stderr = function(err, line)
      if err then
        return echo.err("Error running command '" .. cmd "' with arguments " .. vim.inspect(args) .. "\n:" .. err)
      elseif line ~= nil then
        stderr_lines[#stderr_lines + 1] = line
      end
    end,
    on_exit = function(_, code, _)
      --- NOTE: commands like `rg` return a non-zero exit code when there are no matches, which is okay.
      --- So we only log no-zero exit codes as errors when there's also stderr lines.
      if code > 0 and #stderr_lines > 0 then
        echo.err(
          "Command '"
            .. cmd
            .. "' with arguments "
            .. vim.inspect(args)
            .. " exited with non-zero exit code "
            .. code
            .. "\n\n[stderr]\n\n"
            .. table.concat(stderr_lines, "\n")
        )
      elseif #stderr_lines > 0 then
        echo.warn(
          "Captured stderr output while running command '"
            .. cmd
            .. " with arguments "
            .. vim.inspect(args)
            .. ":\n"
            .. table.concat(stderr_lines)
        )
      end
      if on_exit ~= nil then
        on_exit(code)
      end
    end,
  }
end

---@param cmd string
---@param args string[]
---@param on_stdout function|? (string) -> nil
---@param on_exit function|? (integer) -> nil
---@return integer exit_code
M.run_job = function(cmd, args, on_stdout, on_exit)
  local job = init_job(cmd, args, on_stdout, on_exit)
  job:sync()
  return job.code
end

---@param cmd string
---@param args string[]
---@param on_stdout function|? (string) -> nil
---@param on_exit function|? (integer) -> nil
M.run_job_async = function(cmd, args, on_stdout, on_exit)
  local job = init_job(cmd, args, on_stdout, on_exit)
  job:start()
end

---@param fn function
---@param timeout integer (milliseconds)
M.throttle = function(fn, timeout)
  local last_call = 0
  local timer = nil

  return function(...)
    if timer ~= nil then
      timer:stop()
    end

    ---@diagnostic disable-next-line undefined-field
    local ms_remaining = timeout - (vim.loop.now() - last_call)

    if ms_remaining > 0 then
      if timer == nil then
        ---@diagnostic disable-next-line: undefined-field
        timer = vim.loop.new_timer()
      end
      local args = { ... }
      timer:start(
        ms_remaining,
        0,
        vim.schedule_wrap(function()
          timer:stop()
          timer:close()
          timer = nil
          ---@diagnostic disable-next-line: undefined-field
          last_call = vim.loop.now()
          fn(unpack(args))
        end)
      )
    else
      ---@diagnostic disable-next-line: undefined-field
      last_call = vim.loop.now()
      fn(...)
    end
  end
end

return M
