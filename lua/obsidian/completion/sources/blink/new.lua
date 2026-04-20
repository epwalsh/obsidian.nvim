local NewNoteSourceBase = require "obsidian.completion.sources.base.new"
local abc = require "obsidian.abc"
local blink_util = require "obsidian.completion.sources.blink.util"

---@class obsidian.completion.sources.blink.NewNoteSource : obsidian.completion.sources.base.NewNoteSourceBase
local NewNoteSource = abc.new_class()

NewNoteSource.incomplete_response = blink_util.incomplete_response
NewNoteSource.complete_response = blink_util.complete_response

function NewNoteSource.new()
  return NewNoteSource.init(NewNoteSourceBase)
end

---Implement the get_completions method of the completion provider
---@param context blink.cmp.Context
---@param resolve fun(self: blink.cmp.CompletionResponse): nil
function NewNoteSource:get_completions(context, resolve)
  local request = blink_util.generate_completion_request_from_editor_state(context)
  local cc = self:new_completion_context(resolve, request)
  self:process_completion(cc)
end

---Implements the execute method of the completion provider
---@param _ blink.cmp.Context
---@param item blink.cmp.CompletionItem
function NewNoteSource:execute(_, item)
  self:process_execute(item)
end

return NewNoteSource
