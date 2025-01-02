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
    name = "nvim_tree_lua",
    dir = "@nvim_tree_lua@",
    config = function()
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
      local function my_on_attach(bufnr)
        local api = require("nvim-tree.api")

        local function opts(desc)
          return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
        end

        local function has_marked_nodes()
          local marked_list = api.marks.list()
	  return next(marked_list) ~= nil
        end

	local function custom_delete(node)
	  if has_marked_nodes() then
	    api.marks.bulk.delete()
	  else
	    api.fs.remove(node)
	  end
        end

        -- custom mappings
        vim.keymap.set("n", "h",              api.node.navigate.parent_close,     opts("Close Directory"))
        vim.keymap.set("n", "<CR>",           api.node.open.edit,                 opts("Open"))
        vim.keymap.set("n", "l",              api.node.open.edit,                 opts("Open"))
        vim.keymap.set("n", "<Tab>",          api.node.open.preview,              opts("Open Preview"))
        vim.keymap.set("n", "a",              api.fs.create,                      opts("Create File Or Directory"))
        vim.keymap.set("n", "c",              api.fs.copy.node,                   opts("Copy"))
        vim.keymap.set("n", "D",              custom_delete,                      opts("Delete"))
        vim.keymap.set("n", "?",              api.tree.toggle_help,               opts("Help"))
        vim.keymap.set("n", "o",              api.node.open.edit,                 opts("Open"))
        vim.keymap.set("n", "p",              api.fs.paste,                       opts("Paste"))
        vim.keymap.set("n", "q",              api.tree.close,                     opts("Close"))
        vim.keymap.set("n", "<C-q>",          api.tree.close,                     opts("Close"))
        vim.keymap.set("n", "r",              api.fs.rename_basename,             opts("Rename: Basename"))
        vim.keymap.set("n", "x",              api.fs.cut,                         opts("Cut"))
        vim.keymap.set("n", ";",              api.marks.toggle,                   opts("Mark"))
        vim.keymap.set("n", ":",              api.marks.clear,                    opts("Clera Marks"))
        vim.keymap.set("n", "M",              api.marks.bulk.move,                opts("Move Marked Nodes"))
        vim.keymap.set("n", "y",              api.fs.copy.filename,               opts("Copy Name"))
        vim.keymap.set("n", "Y",              api.fs.copy.absolute_path,          opts("Copy Absolute Path"))
        vim.keymap.set("n", "<C-n>", "<Nop>", opts(""))
        vim.keymap.set("n", "<C-p>", "<Nop>", opts(""))
      end

      require("nvim-tree").setup({
        on_attach = my_on_attach,
	view = {
          float = {
            enable = true,
          },
	},
        actions = {
          open_file = {
            resize_window = false,
          },
        },
        reload_on_bufenter = true,
        renderer = {
          full_name = true,
	  icons = {
            show = {
              folder_arrow = false,
            },
	    glyphs = {
	      folder = {
		 arrow_closed = "",
		 arrow_open = "",
	      },
	    },
	  },
	},
      })
      vim.keymap.set("n", "<Leader>fo", "<Cmd>NvimTreeToggle<CR>", { silent = true })
    end,
    keys = "<Leader>fo",
  },
}
