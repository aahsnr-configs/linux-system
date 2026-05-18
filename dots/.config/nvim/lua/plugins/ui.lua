-- lua/plugins/ui.lua

return {
    {
        "catppuccin/nvim",
        priority = 1000, -- load first
        lazy = false,    -- must be loaded at startup for colorscheme
        config = function()
            require("catppuccin").setup({
                flavour = "mocha",             -- mocha is the darkest theme
                transparent_background = true, -- enable transparency
                integrations = {
                    cmp = true,
                    gitsigns = true,
                    nvimtree = true,
                    treesitter = true,
                    notify = true,
                    mini = true,
                    telescope = true,
                    lualine = true,
                    bufferline = true,
                    which_key = true,
                    indent_blankline = true,
                    mason = true,
                    trouble = true,
                },
            })
            -- apply the colorscheme
            vim.cmd.colorscheme("catppuccin")
        end,
    },

    {
        "nvim-lualine/lualine.nvim",
        event = "VeryLazy",
        config = function()
            require("lualine").setup({
                options = {
                    theme = "catppuccin",
                    globalstatus = true,
                },
                sections = {
                    lualine_a = { "mode" },
                    lualine_b = { "branch" },
                    lualine_c = { "filename" },
                    lualine_x = { "diagnostics" },
                    lualine_y = { "encoding", "fileformat", "filetype" },
                    lualine_z = { "location", "progress" },
                },
            })
        end,
    },

    {
        "akinsho/bufferline.nvim",
        event = "VeryLazy",
        config = function()
            local bufferline = require("bufferline")
            bufferline.setup({
                options = {
                    highlights = require("catppuccin.groups.integrations.bufferline").get_theme(),
                    show_buffer_close_icons = true,
                    separator_style = "slant",
                },
            })
            -- Keymaps to cycle buffers
            vim.keymap.set("n", "<S-h>", "<cmd>BufferLineCyclePrev<CR>", { desc = "Previous buffer", silent = true })
            vim.keymap.set("n", "<S-l>", "<cmd>BufferLineCycleNext<CR>", { desc = "Next buffer", silent = true })
            -- Close current buffer
            vim.keymap.set("n", "<leader>bd", "<cmd>bd<CR>", { desc = "Close buffer", silent = true })
        end,
    },

    {
        "nvim-tree/nvim-web-devicons",
        lazy = true,
    },

    {
        "folke/noice.nvim",
        event = "VeryLazy",
        dependencies = {
            "MunifTanjim/nui.nvim",
            "rcarriga/nvim-notify",
        },
        config = function()
            require("noice").setup({
                presets = {
                    bottom_search = true,         -- use classic bottom cmdline for search
                    command_palette = true,       -- position the cmdline and popupmenu together
                    long_message_to_split = true, -- long messages go to a split
                    inc_rename = false,           -- enable incremental rename if you like
                    lsp_doc_border = true,        -- add a border to hover docs and signature help
                },
                lsp = {
                    -- override markdown rendering so that **cmp** and other plugins use Treesitter
                    override = {
                        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
                        ["vim.lsp.util.stylize_markdown"] = true,
                        ["cmp.entry.get_documentation"] = true,
                    },
                    progress = {
                        enabled = false, -- fidget.nvim handles LSP progress
                    },
                },
            })
        end,
    },

    {
        "rcarriga/nvim-notify",
        lazy = true,
        opts = {
            background_colour = "#000000",
            timeout = 3000,
        },
    },

    {
        "lukas-reineke/indent-blankline.nvim",
        event = "BufReadPost",
        main = "ibl",
        opts = {
            indent = { char = "│" },
            scope = { enabled = false },
        },
    },

    {
        "echasnovski/mini.indentscope",
        event = "BufReadPost",
        version = "*",
        opts = {
            symbol = "│",
            options = { try_as_border = true },
        },
        config = function(_, opts)
            require("mini.indentscope").setup(opts)
            -- Disable in special buffers (terminal, nofile, etc.)
            vim.api.nvim_create_autocmd("FileType", {
                pattern = { "terminal", "nofile", "prompt", "help", "lazy" },
                callback = function()
                    vim.b.miniindentscope_disable = true
                end,
            })
        end,
    },
}
