local Path = require "obsidian.path"
local workspace = require "obsidian.workspace"

describe("Workspace", function()
  it("should be able to initialize a workspace", function()
    local tmpdir = Path.temp()
    tmpdir:mkdir()
    local ws = workspace.new(tmpdir, { name = "test_workspace" })
    assert.equals("test_workspace", ws.name)
    assert.is_true(tmpdir:resolve() == ws.path)
    tmpdir:rmdir()
  end)

  it("should be able to initialize from cwd", function()
    local ws = workspace.new_from_cwd()
    local cwd = Path.cwd()
    assert.is_true(cwd == ws.path)
  end)
end)
