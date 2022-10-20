local action = require('vfiler/action')
require'vfiler/config'.clear_mappings()
require'vfiler/config'.setup {
  options = {
    columns = 'indent,name,git',
    auto_cd = true,
    auto_resize = true,
    keep = true,
    layout = 'left',
    width = 30,
    show_hidden_files = true,
    listed = false,
    git = {
      enabled = true,
      ignored = true,
      untracked = true,
    },
  },

  mappings = {
    ['.'] = action.toggle_show_hidden,
    ['<BS>'] = action.change_to_parent,
    ['r'] = action.reload,
    ['<C-r>'] = action.sync_with_current_filer,
    ['<C-s>'] = action.toggle_sort,
    ['<CR>'] = action.open,
    ['<S-Space>'] = function(vfiler, context, view)
      action.toggle_select(vfiler, context, view)
      action.move_cursor_up(vfiler, context, view)
    end,
    ['<Space>'] = function(vfiler, context, view)
      action.toggle_select(vfiler, context, view)
      action.move_cursor_down(vfiler, context, view)
    end,
    ['<Tab>'] = action.switch_to_filer,
    ['*'] = action.toggle_select_all,
    ['cc'] = action.copy_to_filer,
    ['dd'] = action.delete,
    ['gg'] = action.move_cursor_top,
    ['h'] = action.close_tree_or_cd,
    ['j'] = action.loop_cursor_down,
    ['k'] = action.loop_cursor_up,
    ['l'] = action.open_tree,
    ['mm'] = action.move_to_filer,
    ['p'] = action.toggle_preview,
    ['q'] = action.quit,
    ['<S-q>'] = action.quit,
    ['R'] = action.rename,
    ['s'] = action.open_by_split,
    ['t'] = action.open_by_tabpage,
    ['v'] = action.open_by_vsplit,
    ['x'] = action.execute_file,
    ['yy'] = action.yank_path,
    ['C'] = action.copy,
    ['D'] = action.delete,
    ['G'] = action.move_cursor_bottom,
    ['J'] = action.jump_to_directory,
    ['K'] = action.new_directory,
    ['L'] = action.switch_to_drive,
    ['M'] = action.move,
    ['N'] = action.new_file,
    ['P'] = action.paste,
    ['S'] = action.change_sort,
    ['U'] = action.clear_selected_all,
    ['YY'] = action.yank_name,
    ['L'] = function(vfiler, context, view)
      vim.cmd([[:exe "normal \<c-w>\l"]])
    end,
    ['H'] = function(vfiler, context, view)
      vim.cmd([[:exe "normal \<c-w>\h"]])
    end,
    ['K'] = function(vfiler, context, view)
      vim.cmd([[:exe "normal \<c-w>\k"]])
    end,
    ['J'] = function(vfiler, context, view)
      vim.cmd([[:exe "normal \<c-w>\j"]])
    end,
    ['<C-n'] = function(vfiler, context, view) end
  },
}

vim.keymap.set('n', '<Leader>fo', ':VFiler<CR>')
