-- ~/.config/nvim/lua/plugins/academic.lua
return {
  -- LaTeX Engine
  {
    "lervag/vimtex",
    ft = "tex",
    config = function()
      vim.g.vimtex_view_method = "zathura"
      vim.g.vimtex_quickfix_open_on_warning = 0
      vim.g.vimtex_compiler_latexmk = { build_dir = "build", continuous = 1 }
    end,
  },

  -- Zettelkasten & Notes
  {
    "mickael-menu/zk-nvim",
    dependencies = "nvim-telescope/telescope.nvim",
    ft = "markdown",
    config = function()
      require("zk").setup({
        picker = "telescope",
        keymaps = {
          ["<leader>zn"] = "zk.new",
          ["<leader>zo"] = "zk.open",
          ["<leader>zg"] = "zk.grep",
        }
      })
    end,
  },
  {
    "epwalsh/obsidian.nvim",
    ft = "markdown",
    config = function()
      require("obsidian").setup({
        workspaces = { { name = "notes", path = "~/Documents/ObsidianVault" } },
        templates = { subdir = "templates", date_format = "%Y-%m-%d", time_format = "%H:%M" },
        completion = { nvim_cmp = true },
        new_notes_location = "notes_subdir",
        notes_subdir = "daily",
      })
    end,
  },

  -- Markdown & Pandoc
  { "MeanderingProgrammer/render-markdown.nvim", ft = "markdown", config = function() require("render-markdown").setup({}) end },
  { "vim-pandoc/vim-pandoc", dependencies = "vim-pandoc/vim-pandoc-syntax", ft = "markdown", config = function() vim.g["pandoc#modules#enabled"] = { "tables", "yaml" } end },

  -- Academic Utilities
  { "chrisbra/csv.vim", ft = "csv" },
  { "dhruvasagar/vim-table-mode", ft = "markdown" },
  { "jbyuki/venn.nvim", cmd = { "VennToggle", "VennStart", "VennStop" }, config = function()
    vim.keymap.set("n", "<leader>tn", function() require("venn").toggle() end, { silent = true })
    vim.keymap.set("v", "<leader>tv", function() require("venn").toggle_visual() end, { silent = true })
  end },
}
