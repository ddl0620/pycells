
local pc = require("pycells")

-- Initialize highlighting for cell markers
pc.setup_highlighting()

vim.api.nvim_create_user_command("PyCellsOpen", function()
  pc.open_repl()
end, {})

-- Open REPL (leader p o)
vim.keymap.set("n", "<leader>po", pc.open_repl, { desc = "Open PyCells REPL" })

vim.keymap.set("n", "<leader>rr", pc.send_cell, { desc = "Run python cell (#%%)" })
vim.keymap.set("v", "<leader>rs", pc.send_selection, { desc = "Run selection" })
vim.keymap.set("n", "<leader>rl", pc.send_line, { desc = "Run current line" })
