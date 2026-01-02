-- Claude Code integration for Neovim
-- https://github.com/coder/claudecode.nvim
-- Replaces GitHub Copilot Chat with Claude Code

return {
  {
    'folke/snacks.nvim',
    priority = 1000,
    lazy = false,
    opts = {},
  },
  {
    'coder/claudecode.nvim',
    dependencies = { 'folke/snacks.nvim' },
    opts = {
      -- Server Configuration
      port_range = { min = 10000, max = 65535 },
      auto_start = true,
      log_level = 'info',
      terminal_cmd = nil,

      -- Send/Focus Behavior
      focus_after_send = true,

      -- Selection Tracking
      track_selection = true,
      visual_demotion_delay_ms = 50,

      -- Terminal Configuration
      terminal = {
        split_side = 'right',
        split_width_percentage = 0.35,
        provider = 'snacks',
        auto_close = true,
        git_repo_cwd = true,
      },

      -- Diff Integration
      diff_opts = {
        auto_close_on_accept = true,
        vertical_split = true,
        open_in_current_tab = true,
        keep_terminal_focus = false,
      },
    },
    config = function(_, opts)
      require('claudecode').setup(opts)

      local map = vim.keymap.set

      -- ============================================================
      -- Basic Controls (Normal mode)
      -- ============================================================
      map('n', '<leader>ac', '<cmd>ClaudeCode<cr>', { desc = 'Toggle Claude' })
      map('n', '<leader>af', '<cmd>ClaudeCodeFocus<cr>', { desc = 'Focus Claude' })
      map('n', '<leader>ar', '<cmd>ClaudeCode --resume<cr>', { desc = 'Resume Claude' })
      map('n', '<leader>aC', '<cmd>ClaudeCode --continue<cr>', { desc = 'Continue Claude' })
      map('n', '<leader>am', '<cmd>ClaudeCodeSelectModel<cr>', { desc = 'Select model' })
      map('n', '<leader>ab', '<cmd>ClaudeCodeAdd %<cr>', { desc = 'Add current buffer' })

      -- Diff management
      map('n', '<leader>aA', '<cmd>ClaudeCodeDiffAccept<cr>', { desc = 'Accept diff' })
      map('n', '<leader>aD', '<cmd>ClaudeCodeDiffDeny<cr>', { desc = 'Deny diff' })

      -- Ask Claude
      map('n', '<leader>ai', function()
        local input = vim.fn.input('Ask Claude: ')
        if input ~= '' then
          vim.cmd('ClaudeCode')
          vim.notify('Type in Claude terminal: ' .. input, vim.log.levels.INFO)
        end
      end, { desc = 'Ask Claude' })

      -- Reset Claude
      map('n', '<leader>al', function()
        vim.cmd('ClaudeCode')
        vim.defer_fn(function()
          vim.cmd('ClaudeCode')
        end, 100)
      end, { desc = 'Reset Claude' })

      -- ============================================================
      -- Visual mode keymaps (send selection + focus)
      -- ============================================================
      local function send_and_focus()
        vim.cmd('ClaudeCodeSend')
        vim.schedule(function()
          vim.cmd('ClaudeCodeFocus')
        end)
      end

      map('v', '<leader>as', '<cmd>ClaudeCodeSend<cr>', { desc = 'Send to Claude' })
      map('v', '<leader>ae', send_and_focus, { desc = 'Explain code' })
      map('v', '<leader>at', send_and_focus, { desc = 'Generate tests' })
      map('v', '<leader>aR', send_and_focus, { desc = 'Review code' })
      map('v', '<leader>aF', send_and_focus, { desc = 'Refactor code' })
      map('v', '<leader>an', send_and_focus, { desc = 'Better naming' })
      map('v', '<leader>ax', send_and_focus, { desc = 'Fix error' })
    end,
  },
}
