local RefsSourceBase = require "obsidian.completion.sources.base.refs"
local abc = require "obsidian.abc"
local blink_util = require "obsidian.completion.sources.blink.util"

---@class obsidian.completion.sources.blink.CompletionItem
---@field label string
---@field new_text string
---@field sort_text string
---@field documentation table|?

---@class obsidian.completion.sources.blink.RefsSource : obsidian.completion.sources.base.RefsSourceBase
local RefsSource = abc.new_class()

RefsSource.incomplete_response = blink_util.incomplete_response
RefsSource.complete_response = blink_util.complete_response

function RefsSource.new()
  return RefsSource.init(RefsSourceBase)
end

---Implement the get_completions method of the completion provider
---@param context blink.cmp.Context
---@param resolve fun(self: blink.cmp.CompletionResponse): nil
function RefsSource:get_completions(context, resolve)
  local request = blink_util.generate_completion_request_from_editor_state(context)
  local cc = self:new_completion_context(resolve, request)
  self:process_completion(cc)
end

return RefsSource
