local log = require "obsidian.log"

describe("log.log()", function()
  assert(log._log_level == nil or log._log_level <= vim.log.levels.INFO)

  it("shouldn't fail even if some formatting args are nil", function()
    log.info("hello '%s', from '%s'", "world", nil)
    log.info("hello '%s', from '%s'", nil, "world")
    log.info "hello '%s', from '%s'"
  end)
end)
