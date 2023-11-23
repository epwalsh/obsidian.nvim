------------------------
-- Testing the Client --
------------------------

local obsidian = require "obsidian"

local client = obsidian.setup { dir = "~/epwalsh-notes/notes" } ---@diagnostic disable-line: missing-fields
for _, note in ipairs(client:search("allennlp", false)) do
  print(note.id)
end
