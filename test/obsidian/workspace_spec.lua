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
      overrides = {
        notes_subdir = "notes",
      },
    },
    {
      name = "cwd_workspace",
      path = os.getenv "PWD",
    },
  },
}

describe("Workspace", function()
  it("should be able to initialize a workspace", function()
    local ws = workspace.new("/tmp/obsidian_test_workspace", { name = "test_workspace" })
    assert.equals("test_workspace", ws.name)
    assert.equals(vim.fn.resolve "/tmp/obsidian_test_workspace", ws.path)
  end)

  it("should be able to initialize from cwd", function()
    local ws = workspace.new_from_cwd()
    local cwd = os.getenv "PWD"
    assert.equals(vim.fn.fnamemodify(vim.fn.getcwd(), ":t"), ws.name)
    assert.equals(cwd, ws.path)
  end)

  it("should return workspace for cwd", function()
    local ws = assert(workspace.get_from_opts(opts))
    assert.equals(opts.workspaces[3].name, ws.name)
    assert.equals(opts.workspaces[3].path, ws.path)
  end)
end)
