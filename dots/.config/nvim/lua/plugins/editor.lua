return {
  {
    "nvim-treesitter/nvim-treesitter",
    event = "BufReadPost", -- Lazy-load after buffer read
    build = ":TSUpdate", -- Keep parsers synchronized on update
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "lua", "python", "javascript", "typescript", "tsx", "html", "css", "json", "yaml", "toml", "markdown", "markdown_inline", "bash", "go", "rust", "vim", "vimdoc" }, -- Language parsers to install
        highlight = { enable = true }, -- Enable Treesitter highlighting
        indent = { enable = true }, -- Enable Treesitter indentation
        autotag = { enable = true }, -- Enable autotag integration (for nvim-ts-autotag)
      })
    end,
  },

  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope", -- Lazy-load on Telescope commands
    dependencies = {
      "nvim-lua/plenary.nvim", -- Required Lua utility library
      "nvim-telescope/telescope-fzf-native.nvim", -- Native fzf sorter for performance
    },
    config = function()
      require("telescope").setup({
        defaults = {
          prompt_prefix = " ", -- Minimal prompt prefix
          selection_caret = " ", -- Minimal selection caret
          path_display = { "smart" }, -- Smart path truncation
          file_ignore_patterns = { "node_modules", ".git/" }, -- Ignore common directories
        },
      })
      require("telescope").load_extension("fzf") -- Load native fzf extension
    end,
    keys = {
      { "<leader>ff", function() require("telescope.builtin").find_files() end, desc = "Find files" }, -- Telescope find_files
      { "<leader>fg", function() require("telescope.builtin").live_grep() end, desc = "Live grep" }, -- Telescope live_grep
      { "<leader>fb", function() require("telescope.builtin").buffers() end, desc = "Buffers" }, -- Telescope buffers
      { "<leader>fh", function() require("telescope.builtin").help_tags() end, desc = "Help tags" }, -- Telescope help_tags
    },
  },

  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make", -- Compile native fzf extension
    lazy = true, -- Only loaded as a dependency
  },

  {
    "windwp/nvim-autopairs",
    event = "InsertEnter", -- Lazy-load when entering insert mode
    config = function()
      require("nvim-autopairs").setup({ check_ts = true }) -- Enable Treesitter-aware pairing
      local cmp_autopairs = require("nvim-autopairs.completion.cmp") -- Autopairs completion source
      local cmp = require("cmp") -- nvim-cmp instance
      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done()) -- Insert pair on completion confirm
    end,
  },

  { "numToStr/Comment.nvim", event = "BufReadPost", opts = {} }, -- Lightweight commenting utilities
  { "kylechui/nvim-surround", event = "BufReadPost", version = "*", opts = {} }, -- Surround text objects
  { "windwp/nvim-ts-autotag", event = "BufReadPost", opts = {} }, -- Auto-close and rename HTML/JSX tags
}
