local workspace = require "obsidian.workspace"

local opts = {
  workspaces = {
    {
      name = "work",
      path = "~/notes/work",
    },
    {
      name = "personal",
      path = "~/notes/personal",
    },
    {
      name = "cwd_workspace",
      path = os.getenv "PWD",
    },
  },
  detect_cwd = false,
}

describe("Workspace", function()
  it("should be able to initialize a workspace", function()
    local ws = workspace.new("test_workspace", "/tmp/obsidian_test_workspace")
    assert.equals("test_workspace", ws.name)
    assert.equals("/tmp/obsidian_test_workspace", ws.path)
  end)

  it("should be able to initialize from cwd", function()
    local ws = workspace.new_from_cwd()
    local cwd = os.getenv "PWD"
    assert.equals(".", ws.name)
    assert.equals(cwd, ws.path)
  end)

  it("should be able to retrieve the default workspace", function()
    local ws = workspace.get_default_workspace(opts.workspaces)
    assert.is_not(ws, nil)
    assert.equals(opts.workspaces[1].name, ws.name)
    assert.equals(opts.workspaces[1].path, ws.path)
  end)

  it("should initialize workspace from cwd", function()
    local ws = workspace.get_workspace_from_cwd(opts.workspaces)
    assert.equals(opts.workspaces[3].name, ws.name)
    assert.equals(opts.workspaces[3].path, ws.path)
  end)

  it("should return cwd workspace when detect_cwd is true", function()
    local old_cwd = opts.detect_cwd
    opts.detect_cwd = true
    local ws = workspace.get_from_opts(opts)
    assert.equals(opts.workspaces[3].name, ws.name)
    assert.equals(opts.workspaces[3].path, ws.path)
    opts.detect_cwd = old_cwd
  end)
  it("should return default workspace when detect_cwd is false", function()
    local old_cwd = opts.detect_cwd
    opts.detect_cwd = false
    local ws = workspace.get_from_opts(opts)
    assert.equals(opts.workspaces[1].name, ws.name)
    assert.equals(opts.workspaces[1].path, ws.path)
    opts.detect_cwd = old_cwd
  end)
end)
