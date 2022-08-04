------------------------
-- Testing the Client --
------------------------

local obsidian = require "obsidian"

local client = obsidian.setup { dir = "~/epwalsh-notes/notes" }
for note in client:search "allennlp" do
  print(note.id)
end
