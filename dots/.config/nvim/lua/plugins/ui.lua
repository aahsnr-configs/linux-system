-- ~/.config/nvim/lua/plugins/ui.lua
return {
  { "catppuccin/nvim", name = "catppuccin", priority = 1000, config = function() require("catppuccin").setup({ flavour = "macchiato" }); vim.cmd.colorscheme("catppuccin") end },
  { "nvim-lualine/lualine.nvim", event = "VeryLazy", config = function() require("lualine").setup({ options = { theme = "catppuccin" } }) end },
  { "akinsho/bufferline.nvim", event = "VeryLazy", config = function() require("bufferline").setup({ options = { mode = "tabs", show_close_icon = true } }) end },
  { "nvim-tree/nvim-web-devicons", lazy = true },
  { "lukas-reineke/indent-blankline.nvim", event = "BufReadPost", config = function() require("ibl").setup({ indent = { highlight = { "LineNr" } } }) end },

  -- Modern UI Suite (snacks.nvim)
  {
    "folke/snacks.nvim",
    priority = 1000,
    config = function()
      require("snacks").setup({
        dashboard = { enabled = true },
        notifier = { enabled = true, timeout = 3000 },
        indent = { enabled = true, animate = { enabled = true } },
        terminal = { enabled = true, win = { style = "float" } },
        picker = { enabled = true },
      })
    end,
  },

  { "nvim-neo-tree/neo-tree.nvim", cmd = "Neotree", config = function()
    require("neo-tree").setup({ filesystem = { filtered_items = { hide_dotfiles = false, hide_gitignored = true } } })
  end },
  { "folke/trouble.nvim", dependencies = "nvim-web-devicons", cmd = "Trouble", config = function() require("trouble").setup() end },
}
