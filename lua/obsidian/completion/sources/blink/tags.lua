local TagsSourceBase = require "obsidian.completion.sources.base.tags"
local abc = require "obsidian.abc"
local blink_util = require "obsidian.completion.sources.blink.util"

---@class obsidian.completion.sources.blink.TagsSource : obsidian.completion.sources.base.TagsSourceBase
local TagsSource = abc.new_class()

TagsSource.incomplete_response = blink_util.incomplete_response
TagsSource.complete_response = blink_util.complete_response

function TagsSource.new()
  return TagsSource.init(TagsSourceBase)
end

---Implements the get_completions method of the completion provider
---@param context blink.cmp.Context
---@param resolve fun(self: blink.cmp.CompletionResponse): nil
function TagsSource:get_completions(context, resolve)
  local request = blink_util.generate_completion_request_from_editor_state(context)
  local cc = self:new_completion_context(resolve, request)
  self:process_completion(cc)
end

---Implements the execute method of the completion provider
---@param _ blink.cmp.Context
---@param item blink.cmp.CompletionItem
function TagsSource:execute(_, item)
  self:process_execute(item)
end

return TagsSource
