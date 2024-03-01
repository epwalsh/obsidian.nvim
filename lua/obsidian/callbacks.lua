local abc = require "obsidian.abc"
local log = require "obsidian.log"

local M = {}

---@class obsidian.CallbackManager : obsidian.ABC
---
---@field client obsidian.Client
---@field callbacks obsidian.config.CallbackConfig
CallbackManager = abc.new_class()
M.CallbackManager = CallbackManager

---@param client obsidian.Client
---@param callbacks obsidian.config.CallbackConfig
CallbackManager.new = function(client, callbacks)
  local self = CallbackManager.init()
  self.client = client
  self.callbacks = callbacks
  return self
end

---@param event string
---@param callback fun(...)
---@param ... any
---@return boolean success
local function fire_callback(event, callback, ...)
  local ok, err = pcall(callback, ...)
  if ok then
    return true
  else
    log.error("Error running %s callback: %s", event, err)
    return false
  end
end

---@return boolean|? success
CallbackManager.post_setup = function(self)
  if self.callbacks.post_setup then
    return fire_callback("post_setup", self.callbacks.post_setup, self.client)
  end
end

---@param note obsidian.Note
---@return boolean|? success
CallbackManager.enter_note = function(self, note)
  if self.callbacks.enter_note then
    return fire_callback("enter_note", self.callbacks.enter_note, self.client, note)
  end
end

---@param note obsidian.Note
---@return boolean|? success
CallbackManager.pre_write_note = function(self, note)
  if self.callbacks.pre_write_note then
    return fire_callback("pre_write_note", self.callbacks.pre_write_note, self.client, note)
  end
end

return M
