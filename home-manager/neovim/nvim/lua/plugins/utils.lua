return {
  {
    name = "winresize-nvim",
    dir = "@winresize_nvim@",
    config = function()
      vim.keymap.set("n", "<C-h>", function() require("winresize").resize(0, 2, "left") end)
      vim.keymap.set("n", "<C-j>", function() require("winresize").resize(0, 1, "down") end)
      vim.keymap.set("n", "<C-k>", function() require("winresize").resize(0, 1, "up") end)
      vim.keymap.set("n", "<C-l>", function() require("winresize").resize(0, 2, "right") end)
    end,
    event = "BufEnter",
  },
  {
    name = "fzf_lua",
    dir = "@fzf_lua@",
    config = function()
      vim.keymap.set("n", "<Leader>fs", "<Cmd>lua require('fzf-lua').live_grep()<CR>")
      vim.keymap.set("n", "<Leader>ff", "<Cmd>lua require('fzf-lua').files()<CR>")
      vim.keymap.set("n", "<Leader>fb", "<Cmd>lua require('fzf-lua').blines()<CR>")
    end,
    keys = { "<Leader>fs", "<Leader>ff", "<Leader>fb" },
  },
  {
    name = "neo_tree_nvim",
    dir = "@neo_tree_nvim@",
    dependencies = {
      { name = "nvim_web_devicons", dir = "@nvim_web_devicons@" },
      { name = "plenary_nvim", dir = "@plenary_nvim@" },
      { name = "nui_nvim", dir = "@nui_nvim@" },
    },
    config = function()
      require("neo-tree").setup({
          ["filesystem"] = {
	      ["filtered_items"] = {
	          ["hide_dotfiles"] = false,
		  ["hide_gitignored"] = false,
	      },
	      ["follow_current_file"] = {
	          enabled = true,
	      },
	  },
          ["popup_border_style"] = "solid",
          ["use_default_mappings"] = false,
          ["window"] = {
              ["mappings"] = {
                  ["<C-q>"] = "close_window",
                  ["<cr>"] = "open",
                  ["?"] = "show_help",
                  ["S"] = { "open_split" },
                  ["h"] = { "close_node" },
                  ["l"] = { "open" },
                  ["q"] = "close_window",
                  ["r"] = "refresh",
                  ["s"] = { "open_vsplit" },
              },
          },
      })
      vim.keymap.set("n", "<Leader>fo", "<Cmd>Neotree action=focus reveal toggle<CR>", { silent = true })
      vim.api.nvim_create_autocmd("FileType", {
          group = vim.api.nvim_create_augroup("my_neo_tree", { clear = true }),
          pattern = "neo-tree",
          callback = function()
              vim.bo.buflisted = false
              vim.keymap.set("n", "<C-n>", "<Nop>", { buffer = true })
              vim.keymap.set("n", "<C-p>", "<Nop>", { buffer = true })
              vim.keymap.set("n", "<Leader>fe", "<Nop>", { buffer = true })
              vim.keymap.set("n", "<Leader>ff", "<Nop>", { buffer = true })
          end,
      })
    end,
    keys = "<Leader>fo",
  },
  {
    name = "nvim_surround",
    dir = "@nvim_surround@",
    config = function()
      require("nvim-surround").setup({})
    end,
    event = "InsertEnter",
  },
  {
    name = "openingh_nvim",
    dir = "@openingh_nvim@",
    config = function()
      vim.keymap.set("n", "<Leader>ho", "<Cmd>OpenInGHFile<CR>")
      vim.keymap.set("v", "<Leader>ho", "<Esc><Cmd>'<,'>OpenInGHFile<CR>")
    end,
    keys = { { "<Leader>ho", mode = "n" }, { "<Leader>ho", mode = "v" } },
  },
  {
    name = "nvim_osc52",
    dir = "@nvim_osc52@",
    config = function()
      vim.keymap.set("v", "<leader>y", require("osc52").copy_visual)
      vim.api.nvim_create_autocmd("TextYankPost", {
          group = vim.api.nvim_create_augroup("my_nvim_osc52", { clear = true }),
          pattern = "*",
          callback = function()
              if vim.v.event.operator == "y" then
                  require("osc52").copy_register("")
              end
          end,
      })
    end,
    event = "BufEnter",
  },
  {
    name = "hop_nvim",
    dir = "@hop_nvim@",
    config = function()
      require'hop'.setup { keys = 'etovxqpdygfblzhckisuran' }
      vim.keymap.set("n", "<leader><leader>", require('hop').hint_words)
      vim.keymap.set("v", "<leader><leader>", function() require('hop').hint_words({ hint_position = require('hop.hint').HintPosition.END }) end)
    end,
    event = "VeryLazy",
  },
  {
    name = "oil_nvim",
    dir = "@oil_nvim@",
    config = function()
      require("oil").setup({
        use_default_keymaps = false,
        keymaps = {
          ["<CR>"] = "actions.select",
          ["<C-p>"] = "actions.preview",
          ["<C-q>"] = "actions.close",
          ["<C-r>"] = "actions.refresh",
          ["<S-h>"] = "actions.parent",
        },
        view_options = {
          show_hidden = true,
        },
      })
      vim.keymap.set("n", "<Leader>fe", require("oil").open_float, { desc = "Open parent directory" })
      vim.api.nvim_create_autocmd("FileType", {
          group = vim.api.nvim_create_augroup("my_oil", { clear = true }),
          pattern = "oil",
          callback = function()
              vim.bo.buflisted = false
              vim.keymap.set("n", "<C-n>", "<Nop>", { buffer = true })
              vim.keymap.set("n", "<C-p>", "<Nop>", { buffer = true })
              vim.keymap.set("n", "<Leader>fe", "<Nop>", { buffer = true })
              vim.keymap.set("n", "<Leader>fo", "<Nop>", { buffer = true })
              vim.keymap.set("n", "<Leader>ff", "<Nop>", { buffer = true })
          end,
      })
    end,
    keys = { "<Leader>fe", mode = "n" },
  },
}
