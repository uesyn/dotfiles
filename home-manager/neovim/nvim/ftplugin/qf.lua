vim.bo.buflisted = false
vim.keymap.set("n", "<C-q>", vim.cmd["cclose"], { desc = "Close quickfix", buffer = true })
vim.keymap.set("n", "<C-n>", "<Nop>", { buffer = true })
vim.keymap.set("n", "<C-p>", "<Nop>", { buffer = true })
