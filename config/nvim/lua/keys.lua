-- Save without overriding Escape's normal cancel behavior.
vim.keymap.set('n', '<leader>w', '<cmd>write<cr>', { desc = 'Save' })

vim.keymap.set('n', '<C-a>', 'ggVG', { desc = 'Select All' })

-- Pasting over a selection no longer clobbers the clipboard.
vim.keymap.set('x', 'p', function()
  return 'pgv"' .. vim.v.register .. 'y'
end, { expr = true, desc = 'Paste without replacing register' })
