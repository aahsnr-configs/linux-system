-- ~/.config/nvim/lua/plugins/editor.lua
return {
  -- Syntax & Parsing
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "c", "cpp", "python", "lua", "javascript", "typescript", "rust", "go", "bash", "markdown", "markdown_inline", "latex", "vimdoc", "json", "yaml", "toml", "html", "css", "sql", "regex" },
        auto_install = true,
        sync_install = false,
        ignore_install = {},
        highlight = {
          enable = true,
          disable = function(lang, buf)
            local max_filesize = 100 * 1024
            local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
            if ok and stats and stats.size > max_filesize then
              return true
            end
            return false
          end,
          additional_vim_regex_highlighting = false,
        },
        indent = { enable = true },
        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = "<C-space>",
            node_incremental = "<C-space>",
            scope_incremental = false,
            node_decremental = "<bs>",
          },
        },
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = "@class.inner",
            },
          },
          move = {
            enable = true,
            set_jumps = true,
            goto_next_start = {
              ["]f"] = "@function.outer",
              ["]c"] = "@class.outer",
            },
            goto_next_end = {
              ["]F"] = "@function.outer",
              ["]C"] = "@class.outer",
            },
            goto_previous_start = {
              ["[f"] = "@function.outer",
              ["[c"] = "@class.outer",
            },
          },
        },
      })
    end,
  },

  -- Fuzzy Finder
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = { "nvim-lua/plenary.nvim", { "nvim-telescope/telescope-fzf-native.nvim", build = "make" } },
    config = function()
      local telescope = require("telescope")
      telescope.setup({
        defaults = {
          path_display = { "smart" },
          winblend = 8,
          file_ignore_patterns = { "node_modules", ".git/", "build/", "dist/" },
        },
      })
      pcall(function()
        telescope.load_extension("fzf")
      end)
    end,
  },

  -- Completion & Snippets
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      cmp.setup({
        snippet = {
          expand = function(args)
            if vim.fn.has("nvim-0.10") == 1 then
              vim.snippet.expand(args.body)
            else
              luasnip.lsp_expand(args.body)
            end
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "path" },
          { name = "buffer" }
        }),
        formatting = {
          format = function(_, item)
            local icons = {
              Text = "",
              Method = "󰆧",
              Function = "",
              Constructor = "",
              Field = "󰜢",
              Variable = "",
              Class = "",
              Interface = "",
              Module = "",
              Property = "󰜢",
              Unit = "󰑭",
              Value = "󰎠",
              Enum = "",
              Keyword = "",
              Snippet = "",
              Color = "󰏘",
              File = "",
              Reference = "󰈇",
              Folder = "",
              EnumMember = "",
              Constant = "󰏿",
              Struct = "",
              Event = "",
              Operator = "",
              TypeParameter = "󰊄",
            }
            item.kind = string.format("%s %s", icons[item.kind] or "", item.kind)
            return item
          end,
        },
        confirm_opts = {
          behavior = cmp.ConfirmBehavior.Replace,
          select = false,
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
      })
    end,
    dependencies = {
      "L3MON4D3/LuaSnip",
      build = "make install_jsregexp",
      config = function()
        require("luasnip").config.set_config({
          history = true,
          enable_autosnippets = true,
          store_selection_keys = "<Tab>",
        })
      end,
    },
  },
  { "hrsh7th/cmp-nvim-lsp" },
  { "hrsh7th/cmp-buffer" },
  { "hrsh7th/cmp-path" },
  { "saadparwaiz1/cmp_luasnip" },

  -- UX & Navigation
  { "windwp/nvim-autopairs", event = "InsertEnter", config = function() require("nvim-autopairs").setup{} end },
  { "numToStr/Comment.nvim", event = "BufReadPost", config = function() require("Comment").setup{} end },
  { "folke/which-key.nvim", event = "VeryLazy", config = function() require("which-key").setup{} end },
  { "ggandor/leap.nvim", event = "VeryLazy", config = function() require("leap").add_default_mappings() end },
  { "ggandor/flit.nvim", event = "VeryLazy", config = function() require("flit").setup({ keys = "ft", labeled_modes = "nv" }) end },
}
