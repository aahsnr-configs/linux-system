-- ~/.config/nvim/lua/plugins/dap.lua
return {
  { "mfussenegger/nvim-dap", config = function()
    local dap = require("dap")
    dap.adapters.python = { type = "executable", command = "python3", args = { "-m", "debugpy.adapter" } }
    dap.configurations.python = { { type = "python", request = "launch", name = "Launch File", program = "${file}" } }
    dap.adapters.node2 = { type = "executable", command = "node", args = { require("js-debug-adapter").debuggerPath } }
    dap.configurations.javascript = { { type = "node2", request = "launch", name = "Debug", program = "${file}", cwd = vim.fn.getcwd(), sourceMaps = true } }
    dap.configurations.typescript = { { type = "node2", request = "launch", name = "Debug TS", program = "${file}", cwd = vim.fn.getcwd(), sourceMaps = true } }

    vim.keymap.set("n", "<leader>dc", dap.continue)
    vim.keymap.set("n", "<leader>dt", dap.toggle_breakpoint)
    vim.keymap.set("n", "<leader>dso", dap.step_over)
    vim.keymap.set("n", "<leader>dsi", dap.step_into)
    vim.keymap.set("n", "<leader>dsO", dap.step_out)
    vim.keymap.set("n", "<leader>dr", dap.repl.open)
    vim.keymap.set("n", "<leader>dl", dap.run_last)
  end },
  { "rcarriga/nvim-dap-ui", dependencies = "nvim-dap", config = function() require("dapui").setup() end },
  { "theHamsta/nvim-dap-virtual-text", dependencies = "nvim-dap", config = function() require("nvim-dap-virtual-text").setup() end },
  { "mxsdev/nvim-dap-vscode-js", dependencies = "nvim-dap" },
}
