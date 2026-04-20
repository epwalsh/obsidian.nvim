------------------------
-- Testing the Client --
------------------------

local obsidian = require "obsidian"

local client = obsidian.setup { dir = "~/obsidian-nvim/notes" } ---@diagnostic disable-line: missing-fields
for _, note in ipairs(client:find_notes("allennlp", { search = { sort = false } })) do
  print(note.id)
end
