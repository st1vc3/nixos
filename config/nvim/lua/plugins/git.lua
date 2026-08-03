require('neogit').setup({})
require('gitsigns').setup({
  current_line_blame = true,
})

vim.keymap.set('n', '<leader>g', function()
  require('neogit').open()
end, { desc = 'Neogit' })
