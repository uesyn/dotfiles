{pkgs, ...}: {
  programs.nixvim = {
    extraPlugins = with pkgs.vimPlugins; [
      lspsaga-nvim
    ];

    autoGroups = {
      my_lspsaga = {clear = true;};
      my_lspsaga_outline = {clear = true;};
    };

    autoCmd = [
      {
        event = "LspAttach";
        group = "my_lspsaga";
        callback = {
          __raw = ''
            function(args)
              local bufopts = { noremap = true, silent = true, buffer = args.buf }
              vim.keymap.set('n', 'gd', '<Cmd>Lspsaga goto_definition<CR>', bufopts)
              vim.keymap.set('n', 'gD', '<Cmd>Lspsaga peek_definition<CR>', bufopts)
              vim.keymap.set('n', '[e', '<Cmd>Lspsaga diagnostic_jump_next<CR>', bufopts)
              vim.keymap.set('n', ']e', '<Cmd>Lspsaga diagnostic_jump_prev<CR>', bufopts)
              vim.keymap.set('n', '[LSP]h', '<Cmd>Lspsaga hover_doc<CR>', bufopts)
              vim.keymap.set('n', '[LSP]t', '<Cmd>Lspsaga peek_type_definition<CR>', bufopts)
              vim.keymap.set('n', '[LSP]T', '<Cmd>Lspsaga goto_type_definition<CR>', bufopts)
              vim.keymap.set('n', '[LSP]r', '<Cmd>Lspsaga finder<CR>', bufopts)
              vim.keymap.set('n', '[LSP]R', '<Cmd>Lspsaga rename<CR>', bufopts)
              vim.keymap.set('n', '[LSP]a', '<Cmd>Lspsaga code_action<CR>', bufopts)
              vim.keymap.set('n', '[LSP]f', function() vim.lsp.buf.format { async = true } end, bufopts)
              vim.keymap.set('n', '[LSP]i', '<Cmd>Lspsaga incoming_calls<CR>', bufopts)
              vim.keymap.set('n', '[LSP]o', '<Cmd>Lspsaga outgoing_calls<CR>', bufopts)
            end
          '';
        };
      }
      {
        event = "FileType";
        pattern = "sagaoutline";
        group = "my_lspsaga_outline";
        callback = {
          __raw = ''
            function()
              vim.bo.buflisted = false
              vim.keymap.set('n', '<S-q>', ':clo<CR>', { buffer = true })
              vim.keymap.set('n', '<C-n>', '<Nop>', { buffer = true })
              vim.keymap.set('n', '<C-p>', '<Nop>', { buffer = true })
            end
          '';
        };
      }
    ];

    extraConfigLua = ''
      vim.diagnostic.config({
        virtual_text = false
      })

      require('lspsaga').setup({
        code_action = {
          keys = {
            quit = '<S-q>',
          }
        },
        diagnostic = {
          diagnostic_only_current = true,
          show_code_action = false,
            keys = {
              quit = '<S-q>',
            }
        },
        finder = {
          keys = {
            quit = '<S-q>',
          }
        },
        definition = {
          width = 0.95,
          height = 0.95,
            keys = {
              edit = '<CR>',
              quit = '<S-q>',
            }
        },
        callhierarchy = {
          keys = {
            edit = '<CR>',
            quit = '<S-q>',
          }
        },
        rename = {
          keys = {
            quit = '<S-q>',
          }
        },
      })
    '';
  };
}
