---@class obsidian.completion.sources.base.Request.Context.Position
---@field public col integer
---@field public row integer

---A request context class that partially matches cmp.Context to serve as a common interface for completion sources
---@class obsidian.completion.sources.base.Request.Context
---@field public bufnr integer
---@field public cursor obsidian.completion.sources.base.Request.Context.Position|lsp.Position
---@field public cursor_after_line string
---@field public cursor_before_line string

---A request class that partially matches cmp.Request to serve as a common interface for completion sources
---@class obsidian.completion.sources.base.Request
---@field public context obsidian.completion.sources.base.Request.Context
