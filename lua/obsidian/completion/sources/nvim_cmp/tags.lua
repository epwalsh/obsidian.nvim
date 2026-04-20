local TagsSourceBase = require "obsidian.completion.sources.base.tags"
local abc = require "obsidian.abc"
local completion = require "obsidian.completion.tags"
local nvim_cmp_util = require "obsidian.completion.sources.nvim_cmp.util"

---@class obsidian.completion.sources.nvim_cmp.TagsSource : obsidian.completion.sources.base.TagsSourceBase
local TagsSource = abc.new_class()

TagsSource.new = function()
  return TagsSource.init(TagsSourceBase)
end

TagsSource.get_keyword_pattern = completion.get_keyword_pattern

TagsSource.incomplete_response = nvim_cmp_util.incomplete_response
TagsSource.complete_response = nvim_cmp_util.complete_response

function TagsSource:complete(request, callback)
  local cc = self:new_completion_context(callback, request)
  self:process_completion(cc)
end

function TagsSource:execute(item, callback)
  self:process_execute(item)
  return callback {}
end

return TagsSource
