local M = {}

-- used in obsidian/init.lua -> vim.api.nvim_create_autocmd
M.file_patterns = { "*.md", "*.mdx", "*.mdoc" }

-- used in search.lua -> M.build_find_cmd
M.search_pattern = "*.md,*.mdx,*.mdoc"

-- used in client.lua -> Client.path_is_note
M.file_extensions = { ".md", ".mdx", ".mdoc" }

return M
