-- ~/.config/nvim/lua/plugins/git.lua
return {
  {
    "lewis6991/gitsigns.nvim",
    event = "BufReadPost",
    config = function()
      require("gitsigns").setup({
        signs = { add = { text = "▎" }, change = { text = "▎" }, delete = { text = "▎" } },
        watch_gitdir = { interval = 1000, follow_files = true },
      })
    end,
  },
  { "sindrets/diffview.nvim", cmd = { "DiffviewOpen", "DiffviewClose" }, config = function() require("diffview").setup() end },
  { "tpope/vim-fugitive", cmd = { "Git", "G", "GBrowse", "Gblame" } },
  { "rbong/vim-flog", dependencies = "tpope/vim-fugitive", cmd = "Flog" },
}
