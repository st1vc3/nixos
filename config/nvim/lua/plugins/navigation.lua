require('oil').setup({
  view_options = { show_hidden = true },
})

local snacks = require('snacks')
snacks.setup({
  picker = { enabled = true },
  notifier = { enabled = true },
  input = { enabled = true },
})

vim.keymap.set('n', '<leader>e', '<cmd>Oil<cr>', { desc = 'File Browser' })
vim.keymap.set('n', '<leader>f', function() snacks.picker.files() end, { desc = 'Find Files' })
vim.keymap.set('n', '<leader>s', function() snacks.picker.grep() end, { desc = 'Search Text' })
vim.keymap.set('n', '<leader>b', function() snacks.picker.buffers() end, { desc = 'Buffers' })
vim.keymap.set('n', 'gd', function() snacks.picker.lsp_definitions() end, { desc = 'Goto Definition' })
