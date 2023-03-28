local has_cmp, cmp = pcall(require, "cmp")
if has_cmp then
  cmp.register_source("obsidian_new", require("cmp_obsidian_new").new())
end
