-- lua/plugins/lsp.lua

local function on_attach(client, bufnr)
    -- LSP keymaps (buffer-local)
    local opts = { buffer = bufnr, noremap = true, silent = true }
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "gr", "<cmd>Telescope lsp_references<CR>", opts)
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
    vim.keymap.set("n", "gI", "<cmd>Telescope lsp_implementations<CR>", opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition, opts)

    -- Inlay hints (if supported)
    if client.server_capabilities.inlayHintProvider then
        vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
    end

    -- Disable diagnostics for markdown buffers
    if vim.bo[bufnr].filetype == "markdown" then
        vim.diagnostic.enable(false, { bufnr = bufnr })
    end
end

-- Server-specific settings
local servers = {
    lua_ls = {
        settings = {
            Lua = {
                workspace = { library = vim.api.nvim_get_runtime_file("", true) },
                telemetry = { enable = false },
            },
        },
    },
    marksman = {
        settings = {
            marksman = {
                diagnostics = { enable = false }, -- no linting
            },
        },
    },
    -- Other servers use default settings
}

return {
    {
        "neovim/nvim-lspconfig",
        event = "BufReadPre",
        dependencies = {
            "williamboman/mason.nvim",
            "williamboman/mason-lspconfig.nvim",
            "j-hui/fidget.nvim",
            "hrsh7th/cmp-nvim-lsp",
        },
        config = function()
            -- Capabilities with cmp_nvim_lsp defaults
            local capabilities = vim.lsp.protocol.make_client_capabilities()
            capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

            -- Setup handler for all installed servers
            require("mason-lspconfig").setup_handlers({
                function(server_name)
                    local ok, server = pcall(function()
                        return servers[server_name] or {}
                    end)
                    if not ok then return end

                    local setup = vim.tbl_deep_extend("force", {
                        on_attach = on_attach,
                        capabilities = capabilities,
                    }, server)

                    pcall(function()
                        require("lspconfig")[server_name].setup(setup)
                    end)
                end,
            })
        end,
    },

    {
        "williamboman/mason.nvim",
        cmd = "Mason",
        opts = {
            ui = {
                icons = {
                    package_installed = "✓",
                    package_pending = "➜",
                    package_uninstalled = "✗",
                },
            },
        },
    },

    {
        "williamboman/mason-lspconfig.nvim",
        lazy = true,
        opts = {
            ensure_installed = {
                "lua_ls",
                "pyright",
                "ts_ls",
                "html",
                "cssls",
                "jsonls",
                "gopls",
                "rust_analyzer",
                "bashls",
                "marksman",
            },
            automatic_installation = true,
        },
    },

    {
        "nvimtools/none-ls.nvim",
        event = "BufReadPre",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "williamboman/mason.nvim",
        },
        config = function()
            local null_ls = require("null-ls")
            local sources = {}

            -- Formatters (safe with pcall)
            pcall(function() table.insert(sources, null_ls.builtins.formatting.stylua) end)
            pcall(function() table.insert(sources, null_ls.builtins.formatting.black) end)
            pcall(function() table.insert(sources, null_ls.builtins.formatting.prettierd) end)

            -- Diagnostics only for JS/TS, not markdown
            pcall(function()
                table.insert(sources, null_ls.builtins.diagnostics.eslint_d.with({
                    filetypes = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
                }))
            end)

            null_ls.setup({ sources = sources })
        end,
    },

    {
        "j-hui/fidget.nvim",
        event = "LspAttach",
        opts = {
            notification = {
                window = { winblend = 0 },
            },
        },
    },

    {
        "folke/trouble.nvim",
        cmd = "Trouble",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        opts = {
            use_diagnostic_signs = true,
        },
        keys = {
            { "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>",              desc = "Trouble diagnostics toggle" },
            { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", desc = "Trouble diagnostics (buffer)" },
            { "<leader>cs", "<cmd>Trouble symbols toggle<CR>",                  desc = "Trouble symbols" },
            { "<leader>cl", "<cmd>Trouble lsp toggle<CR>",                      desc = "Trouble LSP" },
        },
    },
}
