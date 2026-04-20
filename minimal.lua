vim.env.LAZY_STDPATH = ".repro"
load(vim.fn.system "curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua")()

vim.fn.mkdir(".repro/vault", "p")

vim.o.conceallevel = 2

local plugins = {
  {
    "obsidian-nvim/obsidian.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      completion = {
        blink = true,
        nvim_cmp = false,
      },
      workspaces = {
        {
          name = "test",
          path = vim.fs.joinpath(vim.uv.cwd(), ".repro", "vault"),
        },
      },
    },
  },

  -- **Choose your renderer**
  { "MeanderingProgrammer/render-markdown.nvim", dependencies = { "echasnovski/mini.icons" }, opts = {} },
  -- { "OXY2DEV/markview.nvim", lazy = false },

  -- **Choose your picker**
  "nvim-telescope/telescope.nvim",
  -- "folke/snacks.nvim",
  -- "ibhagwan/fzf-lua",
  -- "echasnovski/mini.pick",

  {
    "hrsh7th/nvim-cmp",
    config = function()
      local cmp = require "cmp"
      cmp.setup {
        mapping = cmp.mapping.preset.insert {
          ["<C-e>"] = cmp.mapping.abort(),
          ["<C-y>"] = cmp.mapping.confirm { select = true },
        },
      }
    end,
  },
  {
    "saghen/blink.cmp",
    opts = {
      fuzzy = { implementation = "lua" }, -- no need to build binary
      keymap = {
        preset = "default",
      },
    },
  },
}

require("lazy.minit").repro { spec = plugins }

vim.cmd "checkhealth obsidian"
