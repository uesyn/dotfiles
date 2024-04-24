{ pkgs, ... }:
{
  programs.nixvim = {
    extraPackages =  with pkgs; [
      gopls
      nodePackages.typescript-language-server
      nodePackages.bash-language-server
    ];

    extraPlugins = with pkgs.vimPlugins; [
      cmp-nvim-lsp
      nvim-lspconfig
    ];

    autoGroups = {
      my_lspconfig = {
        clear = true;
      };
    };

    autoCmd = [
      {
        event = "LspAttach";
        callback = {
          __raw = ''
            function(args)
              if not (args.data and args.data.client_id) then
                return
              end

              local bufnr = args.buf
              local client = vim.lsp.get_client_by_id(args.data.client_id)
              if client.supports_method("textDocument/inlayHint") or client.server_capabilities.inlayHintProvider then
                vim.lsp.inlay_hint.enable(true)
              end

              vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')
            end
          '';
        };
        group = "my_lspconfig";
      }
    ];

    extraConfigLua = ''
      local lspconfig = require('lspconfig')
      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      lspconfig.gopls.setup {
        handlers = handlers,
        capabilities = capabilities,
        settings = {
          gopls = {
            hints = {
              assignVariableTypes = true,
              compositeLiteralFields = true,
              compositeLiteralTypes = true,
              constantValues = true,
              functionTypeParameters = true,
              parameterNames = false,
              rangeVariableTypes = false,
            },
          },
        },
      }

      lspconfig.tsserver.setup {
        handlers = handlers,
        capabilities = capabilities,
        root_dir = require('lspconfig').util.root_pattern("package.json"),
      }

      lspconfig.denols.setup {
        handlers = handlers,
        capabilities = capabilities,
        root_dir = require('lspconfig').util.root_pattern("deno.json", "deno.jsonc", "deps.ts",
          "import_map.json"),
        settings = {
          denols = {
            enable = true,
            lint = true,
            unstable = true,
            suggest = {
              imports = {
                autoDiscovery = true,
              }
            },
          },
        },
      }

      lspconfig.rust_analyzer.setup {
        -- Server-specific settings. See `:help lspconfig-setup`
        settings = {
          ["rust-analyzer"] = {
            cargo = { allFeatures = true },
            checkOnSave = { allFeatures = true },
            diagnostics = {
              enable = true,
              disabled = { "unresolved-proc-macro" },
              enableExperimental = true,
            },
          },
        },
      }

      lspconfig.bashls.setup {}
    '';
  };
}
