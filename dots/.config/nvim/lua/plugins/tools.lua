return {
    {
        "ThePrimeagen/harpoon",
        branch = "harpoon2",
        dependencies = { "nvim-lua/plenary.nvim" },
        keys = {
            { "<leader>ha", function() require("harpoon"):list():add() end,                                    desc = "Harpoon Add" },
            { "<leader>hh", function() require("harpoon").ui:toggle_quick_menu(require("harpoon"):list()) end, desc = "Harpoon Menu" },
            { "<C-1>",      function() require("harpoon"):list():select(1) end,                                desc = "Harpoon 1" },
            { "<C-2>",      function() require("harpoon"):list():select(2) end,                                desc = "Harpoon 2" },
            { "<C-3>",      function() require("harpoon"):list():select(3) end,                                desc = "Harpoon 3" },
            { "<C-4>",      function() require("harpoon"):list():select(4) end,                                desc = "Harpoon 4" },
        },
        config = function() require("harpoon"):setup() end,
    },

    {
        "stevearc/oil.nvim",
        cmd = "Oil",
        keys = {
            { "<leader>e", "<cmd>Oil --float<cr>", desc = "Oil (float)" },
        },
        opts = {
            default_file_explorer = true,
            columns = { "icon" },
            keymaps = {
                ["<C-h>"] = false,
                ["g."] = "actions.toggle_hidden",
            },
            view_options = {
                show_hidden = true,
            },
            float = {
                padding = 2,
                border = "rounded",
            },
        },
    },

    {
        "akinsho/toggleterm.nvim",
        version = "*",
        keys = {
            { "<leader>t", "<cmd>ToggleTerm direction=float<cr>", desc = "Toggle Terminal" },
        },
        opts = {
            size = 20,
            open_mapping = nil,
            shade_terminals = true,
            shading_factor = 2,
            direction = "float",
            float_opts = {
                border = "curved",
            },
        },
        config = function(_, opts)
            require("toggleterm").setup(opts)
            local Terminal = require("toggleterm.terminal").Terminal
            local lazygit = Terminal:new({
                cmd = "lazygit",
                hidden = true,
                direction = "float",
                float_opts = { border = "double" },
            })
            vim.keymap.set("n", "<leader>gg", function() lazygit:toggle() end,
                { desc = "LazyGit", noremap = true, silent = true })
            vim.keymap.set("n", "<C-\\>", "<cmd>ToggleTerm<cr>",
                { desc = "Toggle Terminal", noremap = true, silent = true })
        end,
    },

    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        version = "*",
        config = function()
            local wk = require("which-key")
            wk.setup({})
            wk.register({
                ["<leader>f"] = { name = "[F]ind" },
                ["<leader>h"] = { name = "[H]arpoon" },
                ["<leader>g"] = { name = "[G]it" },
                ["<leader>x"] = { name = "Trouble" },
                ["<leader>c"] = { name = "[C]ode" },
                ["<leader>t"] = { name = "[T]erminal" },
                ["<leader>s"] = { name = "[S]plit" },
            })
        end,
    },

    {
        "folke/flash.nvim",
        event = "VeryLazy",
        ---@type Flash.Config
        opts = {},
        keys = {
            { "s",     mode = { "n", "x", "o" }, function() require("flash").jump() end,              desc = "Flash" },
            { "S",     mode = { "n", "x", "o" }, function() require("flash").treesitter() end,        desc = "Flash Treesitter" },
            { "r",     mode = "o",               function() require("flash").remote() end,            desc = "Remote Flash" },
            { "R",     mode = { "o", "x" },      function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
            { "<c-s>", mode = { "c" },           function() require("flash").toggle() end,            desc = "Toggle Flash Search" },
        },
    },
}
