return {
  {
    'echasnovski/mini.files',
    version = false,
    dependencies = {
      "nvim-web-devicons",
    },
    keys = "<Leader>fo",
    enabled = false,
    config = function()
      require('mini.files').setup({
        mappings = {
          close       = '<Leader>fo',
          go_in       = 'l',
          go_in_plus  = 'L',
          go_out      = 'h',
          go_out_plus = 'H',
          reset       = '<BS>',
          show_help   = '?',
          synchronize = '=',
          trim_left   = '<',
          trim_right  = '>',
        },
      })
      vim.keymap.set('n', '<Leader>fo', ':lua MiniFiles.open()<CR>', { silent = true })
      vim.api.nvim_create_augroup('minifiles', {})
      vim.api.nvim_create_autocmd("FileType", {
        group = 'minifiles',
        pattern = 'minifiles',
        callback = function()
          vim.keymap.set('n', '<C-n>', '<Nop>', { buffer = true })
          vim.keymap.set('n', '<C-p>', '<Nop>', { buffer = true })
          vim.keymap.set('n', '<S-q>', '<Nop>', { buffer = true })
          vim.keymap.set('n', '<S-k>', '<Nop>', { buffer = true })
        end
      })
      vim.api.nvim_create_augroup('minifiles-help', {})
      vim.api.nvim_create_autocmd("FileType", {
        group = 'minifiles-help',
        pattern = 'minifiles-help',
        callback = function()
          vim.keymap.set('n', '<C-n>', '<Nop>', { buffer = true })
          vim.keymap.set('n', '<C-p>', '<Nop>', { buffer = true })
          vim.keymap.set('n', '<S-q>', '<Nop>', { buffer = true })
          vim.keymap.set('n', '<Leader>fo', '<Nop>', { buffer = true })
        end
      })
    end
  },

  {
    "nvim-tree/nvim-tree.lua",
    dependencies = {
      "nvim-web-devicons",
    },
    enabled = false,
    keys = "<Leader>fo",
    config = function()
      vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
      vim.opt.termguicolors = true

      vim.keymap.set('n', '<Leader>fo', '<Cmd>NvimTreeToggle<CR>')

      -- OR setup with some options
      require("nvim-tree").setup({
        disable_netrw = false,
        hijack_cursor = false,
        hijack_netrw = true,
        sort_by = "case_sensitive",
        view = {
          adaptive_size = true,
          mappings = {
            custom_only = true,
            list = {
              { key = "u",    action = "dir_up" },
              { key = "<CR>", action = "cd" },
              { key = "l",    action = "edit" },
              { key = "h",    action = "close_node" },
              { key = "p",    action = "preview" },
              { key = "r",    action = "refresh" },
              { key = "F",    action = "create" },
              { key = "D",    action = "remove" },
              { key = "R",    action = "full_rename" },
              { key = "c",    action = "copy" },
              { key = "x",    action = "cut" },
            },
          },
        },
        renderer = {
          group_empty = true,
        },
        filters = {
          dotfiles = false,
        },
      })
    end,
  },

  {
    'nvim-neo-tree/neo-tree.nvim',
    dependencies = {
      'plenary.nvim',
      'nvim-web-devicons',
      'MunifTanjim/nui.nvim',
    },
    enabled = true,
    keys = { "<Leader>fo" },
    branch = "v3.x",
    -- keys = "<Leader>fo",
    init = function()
      vim.g.neo_tree_remove_legacy_commands = 1
    end,
    config = function()
      -- If you want icons for diagnostic errors, you'll need to define them somewhere:
      vim.fn.sign_define("DiagnosticSignError",
        { text = " ", texthl = "DiagnosticSignError" })
      vim.fn.sign_define("DiagnosticSignWarn",
        { text = " ", texthl = "DiagnosticSignWarn" })
      vim.fn.sign_define("DiagnosticSignInfo",
        { text = " ", texthl = "DiagnosticSignInfo" })
      vim.fn.sign_define("DiagnosticSignHint",
        { text = "", texthl = "DiagnosticSignHint" })
      -- NOTE: this is changed from v1.x, which used the old style of highlight groups
      -- in the form "LspDiagnosticsSignWarning"

      require("neo-tree").setup({
        close_if_last_window = false,
        popup_border_style = "solid",
        enable_git_status = true,
        enable_diagnostics = true,
        sort_case_insensitive = false,
        sort_function = nil,
        default_component_configs = {
          container = {
            enable_character_fade = true
          },
          indent = {
            indent_size = 2,
            padding = 1, -- extra padding on left hand side
            -- indent guides
            with_markers = true,
            indent_marker = "│",
            last_indent_marker = "└",
            highlight = "NeoTreeIndentMarker",
            -- expander config, needed for nesting files
            with_expanders = nil, -- if nil and file nesting is enabled, will enable expanders
            expander_collapsed = "",
            expander_expanded = "",
            expander_highlight = "NeoTreeExpander",
          },
          icon = {
            folder_closed = "",
            folder_open = "",
            folder_empty = "ﰊ",
            -- The next two settings are only a fallback, if you use nvim-web-devicons and configure default icons there
            -- then these will never be used.
            default = "*",
            highlight = "NeoTreeFileIcon"
          },
          modified = {
            symbol = "[+]",
            highlight = "NeoTreeModified",
          },
          name = {
            trailing_slash = false,
            use_git_status_colors = true,
            highlight = "NeoTreeFileName",
          },
          git_status = {
            symbols = {
              -- Change type
              added     = "",  -- or "✚", but this is redundant info if you use git_status_colors on the name
              modified  = "",  -- or "", but this is redundant info if you use git_status_colors on the name
              deleted   = "✖", -- this can only be used in the git_status source
              renamed   = "", -- this can only be used in the git_status source
              -- Status type
              untracked = "",
              ignored   = "",
              unstaged  = "",
              staged    = "",
              conflict  = "",
            }
          },
        },
        use_default_mappings = false,
        window = {
          position = "left",
          width = 40,
          mapping_options = {
            noremap = true,
            nowait = true,
          },
          mappings = {
            -- ["<space>"] = {
            --     "toggle_node",
            --     nowait = false, -- disable `nowait` if you have existing combos starting with this char that you want to use
            -- },
            ["<cr>"] = "open",
            ["l"] = "open",
            ["<esc>"] = "revert_preview",
            ["P"] = { "toggle_preview", config = { use_float = true } },
            ["S"] = "open_split",
            ["s"] = "open_vsplit",
            -- ["S"] = "split_with_window_picker",
            -- ["s"] = "vsplit_with_window_picker",
            -- ["t"] = "open_tabnew",
            -- ["<cr>"] = "open_drop",
            -- ["t"] = "open_tab_drop",
            -- ["w"] = "open_with_window_picker",
            -- ["P"] = "toggle_preview", -- enter preview mode, which shows the current node without focusing
            ["h"] = "close_node",
            -- ["z"] = "close_all_nodes",
            -- ["Z"] = "expand_all_nodes",
            ["F"] = {
              "add",
              -- this command supports BASH style brace expansion ("x{a,b,c}" -> xa,xb,xc). see `:h neo-tree-file-actions` for details
              -- some commands may take optional config options, see `:h neo-tree-mappings` for details
              config = {
                show_path = "absolute" -- "none", "relative", "absolute"
              }
            },
            ["K"] = {
              "add_directory",
              config = {
                show_path = "absolute" -- "none", "relative", "absolute"
              }
            },
            ["D"] = "delete",
            ["R"] = "rename",
            ["y"] = "copy_to_clipboard",
            ["x"] = "cut_to_clipboard",
            ["p"] = "paste_from_clipboard",
            ["c"] = "copy", -- takes text input for destination, also accepts the optional config.show_path option like "add":
            -- ["c"] = {
            --  "copy",
            --  config = {
            --    show_path = "none" -- "none", "relative", "absolute"
            --  }
            --}
            ["m"] = {
              "move", -- takes text input for destination, also accepts the optional config.show_path option like "add".
              config = {
                show_path = "absolute"
              }
            },
            ["q"] = "close_window",
            ["r"] = "refresh",
            ["?"] = "show_help",
            ["<"] = "prev_source",
            [">"] = "next_source",
          }
        },
        nesting_rules = {},
        filesystem = {
          filtered_items = {
            visible = false, -- when true, they will just be displayed differently than normal items
            hide_dotfiles = false,
            hide_gitignored = false,
            hide_hidden = true, -- only works on Windows for hidden files/directories
            hide_by_name = {
              --"node_modules"
            },
            hide_by_pattern = { -- uses glob style patterns
              --"*.meta",
              --"*/src/*/tsconfig.json",
            },
            always_show = { -- remains visible even if other settings would normally hide it
              --".gitignored",
            },
            never_show = { -- remains hidden even if visible is toggled to true, this overrides always_show
              --".DS_Store",
              --"thumbs.db"
            },
            never_show_by_pattern = { -- uses glob style patterns
              --".null-ls_*",
            },
          },
          follow_current_file = {
            enabled = false, -- This will find and focus the file in the active buffer every
          },
          -- time the current file is changed while the tree is open.
          group_empty_dirs = false,               -- when true, empty folders will be grouped together
          hijack_netrw_behavior = "open_default", -- netrw disabled, opening a directory opens neo-tree
          -- in whatever position is specified in window.position
          -- "open_current",  -- netrw disabled, opening a directory opens within the
          -- window like netrw would, regardless of window.position
          -- "disabled",    -- netrw left alone, neo-tree does not handle opening dirs
          use_libuv_file_watcher = false, -- This will use the OS level file watchers to detect changes
          -- instead of relying on nvim autocmd events.
        },
        buffers = {
          follow_current_file = {
            enabled = false, -- This will find and focus the file in the active buffer every
          },
          -- time the current file is changed while the tree is open.
          group_empty_dirs = true,    -- when true, empty folders will be grouped together
          show_unloaded = true,
        },
        git_status = {
          window = {
            position = "float",
          }
        }
      })

      vim.keymap.set('n', '<Leader>fo', '<Cmd>Neotree reveal toggle<CR>)')
    end
  },
}
