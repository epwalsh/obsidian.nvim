------------------------
-- Testing the Client --
------------------------

local obsidian = require "obsidian"

local client = obsidian.setup { dir = "~/epwalsh-notes/notes" }
for _, note in ipairs(client:search "allennlp") do
  print(note.id)
end
