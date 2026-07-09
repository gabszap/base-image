if vim.env.TMUX then
  local script = vim.env.HOME .. '/.config/tmux/plugins/tmux-window-name/scripts/rename_session_windows.py'
  vim.cmd('autocmd VimEnter,VimLeave * call jobstart(["python3", "' .. script .. '"], {"detach": 1})')
end

vim.opt.number = true