local has_cmp, cmp = pcall(require, "cmp")
if has_cmp then
  cmp.register_source("obsidian", require("cmp_obsidian").new())
end
