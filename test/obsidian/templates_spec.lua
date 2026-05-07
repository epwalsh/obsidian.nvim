local obsidian = require "obsidian"
local Path = require "obsidian.path"
local Note = require "obsidian.note"
local templates = require "obsidian.templates"

---Get a client in a temporary directory.
---
---@return obsidian.Client
local tmp_client = function()
  -- This gives us a tmp file name, but we really want a directory.
  -- So we delete that file immediately.
  local tmpname = os.tmpname()
  os.remove(tmpname)

  local dir = Path:new(tmpname .. "-obsidian/")
  dir:mkdir { parents = true }

  return obsidian.new_from_dir(tostring(dir))
end

describe("templates.substitute_template_variables()", function()
  ---@type obsidian.Client
  local client

  before_each(function()
    client = tmp_client()
  end)

  it("should substitute built-in variables", function()
    local text = "today is {{date}} and the title of the note is {{title}}"
    assert.equal(
      string.format("today is %s and the title of the note is %s", os.date "%Y-%m-%d", "FOO"),
      templates.substitute_template_variables(text, client, Note.new("FOO", { "FOO" }, {}))
    )
  end)

  describe("when substituting custom variable", function()
    it("should substitute using a string", function()
      client.opts.templates.substitutions = {
        weekday = "Monday",
      }
      local text = "today is {{weekday}}"
      assert.equal("today is Monday", templates.substitute_template_variables(text, client, Note.new("foo", {}, {})))

      -- Make sure the client opts has not been modified.
      assert.equal(1, vim.tbl_count(client.opts.templates.substitutions))
      assert.equal("string", type(client.opts.templates.substitutions.weekday))
    end)

    it("should substitute using a function", function()
      client.opts.templates.substitutions = {
        weekday = function()
          return "Monday"
        end,
      }
      local text = "today is {{weekday}}"
      assert.equal("today is Monday", templates.substitute_template_variables(text, client, Note.new("foo", {}, {})))

      -- Make sure the client opts has not been modified.
      assert.equal(1, vim.tbl_count(client.opts.templates.substitutions))
      assert.equal("function", type(client.opts.templates.substitutions.weekday))
    end)

    it("should substitute using values from the note", function()
      client.opts.templates.substitutions = {
        ---@param note obsidian.Note
        id_uppercase = function(note)
          return string.upper(note.id)
        end,
      }

      local text = "formatted id: {{id_uppercase}}"
      assert.equal("formatted id: FOO", templates.substitute_template_variables(text, client, Note.new("foo", {}, {})))
    end)
  end)
end)
