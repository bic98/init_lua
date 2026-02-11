-- debug.lua
--
-- Shows how to use the DAP plugin to debug your code.
--
-- Primarily focused on configuring the debugger for Go, but can
-- be extended to other languages as well. That's why it's called
-- kickstart.nvim and not kitchen-sink.nvim ;)

return {
  -- NOTE: Yes, you can install new plugins here!
  'mfussenegger/nvim-dap',
  -- NOTE: And you can specify dependencies as well
  dependencies = {
    -- Creates a beautiful debugger UI
    'rcarriga/nvim-dap-ui',

    -- Required dependency for nvim-dap-ui
    'nvim-neotest/nvim-nio',

    -- Installs the debug adapters for you
    'mason-org/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',

    -- Add your own debuggers here
    -- 'leoluz/nvim-dap-go', -- Go 사용 시 주석 해제
  },
  keys = {
    -- Basic debugging keymaps, feel free to change to your liking!
    {
      '<F5>',
      function()
        require('dap').continue()
      end,
      desc = 'Debug: Start/Continue',
    },
    {
      '<F1>',
      function()
        require('dap').step_into()
      end,
      desc = 'Debug: Step Into',
    },
    {
      '<F2>',
      function()
        require('dap').step_over()
      end,
      desc = 'Debug: Step Over',
    },
    {
      '<F3>',
      function()
        require('dap').step_out()
      end,
      desc = 'Debug: Step Out',
    },
    {
      '<leader>b',
      function()
        require('dap').toggle_breakpoint()
      end,
      desc = 'Debug: Toggle Breakpoint',
    },
    {
      '<leader>B',
      function()
        require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
      end,
      desc = 'Debug: Set Breakpoint',
    },
    -- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
    {
      '<F7>',
      function()
        require('dapui').toggle()
      end,
      desc = 'Debug: See last session result.',
    },
    -- 추가 디버깅 키맵
    {
      '<F9>',
      function()
        require('dap').terminate()
      end,
      desc = 'Debug: Stop/Terminate',
    },
    {
      '<F10>',
      function()
        local dap = require('dap')
        -- 메모리에 있으면 그거 사용
        if dap.status() ~= '' then
          dap.run_last()
          return
        end
        -- 파일에 저장된 설정 복원
        local last_config = _G.dap_load_last_config and _G.dap_load_last_config()
        if last_config and last_config.type then
          vim.notify('Restoring: ' .. (last_config.name or 'last session'), vim.log.levels.INFO)
          dap.run(last_config)
        else
          -- 둘 다 없으면 새로 시작
          dap.continue()
        end
      end,
      desc = 'Debug: Run Last (저장된 설정 복원)',
    },
    {
      '<F4>',
      function()
        require('dap').run_to_cursor()
      end,
      desc = 'Debug: Run to Cursor',
    },
    {
      '<leader>dr',
      function()
        require('dap').restart()
      end,
      desc = 'Debug: Restart',
    },
    {
      '<leader>dh',
      function()
        require('dap.ui.widgets').hover()
      end,
      desc = 'Debug: Hover (변수 값)',
    },
    {
      '<leader>dp',
      function()
        require('dap').pause()
      end,
      desc = 'Debug: Pause',
    },
    {
      '<leader>de',
      function()
        require('dapui').eval()
      end,
      mode = { 'n', 'v' },
      desc = 'Debug: Evaluate expression',
    },
  },
  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'

    -- 마지막 설정 저장/복원
    local last_config_file = vim.fn.stdpath 'data' .. '/dap_last_config.json'

    local function save_last_config(config)
      local file = io.open(last_config_file, 'w')
      if file then
        -- 함수는 저장 안 되니까 필요한 것만
        local to_save = {
          name = config.name,
          type = config.type,
          request = config.request,
          program = config.program,
          cwd = config.cwd,
          args = type(config.args) == 'table' and config.args or nil,
        }
        file:write(vim.fn.json_encode(to_save))
        file:close()
      end
    end

    local function load_last_config()
      local file = io.open(last_config_file, 'r')
      if file then
        local content = file:read '*a'
        file:close()
        local ok, config = pcall(vim.fn.json_decode, content)
        if ok then
          return config
        end
      end
      return nil
    end

    -- 디버그 시작 시 설정 저장
    dap.listeners.after.event_initialized['save_config'] = function(session)
      if session.config then
        save_last_config(session.config)
      end
    end

    -- 전역으로 노출 (F10에서 사용)
    _G.dap_load_last_config = load_last_config

    require('mason-nvim-dap').setup {
      -- Makes a best effort to setup the various debuggers with
      -- reasonable debug configurations
      automatic_installation = true,

      -- You can provide additional configuration to the handlers,
      -- see mason-nvim-dap README for more information
      handlers = {},

      -- You'll need to check that you have the required things installed
      -- online, please don't ask me how to install them :)
      ensure_installed = {
        -- Update this to ensure that you have the debuggers for the langs you want
        'debugpy', -- Python
        'js-debug-adapter', -- JavaScript/TypeScript
        'netcoredbg', -- C#
      },
    }

    -- Dap UI setup
    -- For more information, see |:help nvim-dap-ui|
    dapui.setup {
      -- Set icons to characters that are more likely to work in every terminal.
      --    Feel free to remove or use ones that you like more! :)
      --    Don't feel like these are good choices.
      icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
      controls = {
        icons = {
          pause = '⏸',
          play = '▶',
          step_into = '⏎',
          step_over = '⏭',
          step_out = '⏮',
          step_back = 'b',
          run_last = '▶▶',
          terminate = '⏹',
          disconnect = '⏏',
        },
      },
    }

    -- Change breakpoint icons
    -- vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
    -- vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
    -- local breakpoint_icons = vim.g.have_nerd_font
    --     and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
    --   or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
    -- for type, icon in pairs(breakpoint_icons) do
    --   local tp = 'Dap' .. type
    --   local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
    --   vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
    -- end

    dap.listeners.after.event_initialized['dapui_config'] = dapui.open
    dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    dap.listeners.before.event_exited['dapui_config'] = dapui.close

    -- Go 사용 시 주석 해제
    -- require('dap-go').setup {
    --   delve = {
    --     detached = vim.fn.has 'win32' == 0,
    --   },
    -- }

    -- Python 설정
    local debugpy_path = vim.fn.stdpath 'data' .. '/mason/packages/debugpy/venv/bin/python'
    if vim.fn.executable(debugpy_path) == 1 then
      dap.adapters.python = function(cb, config)
        if config.request == 'attach' then
          local port = (config.connect or config).port
          local host = (config.connect or config).host or '127.0.0.1'
          cb {
            type = 'server',
            port = assert(port, '`connect.port` is required for a python `attach` configuration'),
            host = host,
            options = { source_filetype = 'python' },
          }
        else
          cb {
            type = 'executable',
            command = debugpy_path,
            args = { '-m', 'debugpy.adapter' },
            options = { source_filetype = 'python' },
          }
        end
      end
    end

    dap.configurations.python = {
      {
        type = 'python',
        request = 'launch',
        name = 'run_indexing.py (km_rag)',
        program = '/home/inchanbaek/km_rag/company_documents/scripts/run_indexing.py',
        cwd = '/home/inchanbaek/km_rag/company_documents',
        args = function()
          local args_string = vim.fn.input 'Arguments: '
          local args = {}
          for arg in string.gmatch(args_string, '%S+') do
            table.insert(args, arg)
          end
          return args
        end,
        pythonPath = function()
          local venv = os.getenv 'VIRTUAL_ENV'
          if venv then
            return venv .. '/bin/python'
          end
          return '/usr/bin/python3'
        end,
      },
      {
        type = 'python',
        request = 'launch',
        name = 'Launch file',
        program = '${file}',
        pythonPath = function()
          local venv = os.getenv 'VIRTUAL_ENV'
          if venv then
            return venv .. '/bin/python'
          end
          return '/usr/bin/python3'
        end,
      },
      {
        type = 'python',
        request = 'launch',
        name = 'Launch with arguments',
        program = '${file}',
        args = function()
          local args_string = vim.fn.input 'Arguments: '
          local args = {}
          for arg in string.gmatch(args_string, '%S+') do
            table.insert(args, arg)
          end
          return args
        end,
        pythonPath = function()
          local venv = os.getenv 'VIRTUAL_ENV'
          if venv then
            return venv .. '/bin/python'
          end
          return '/usr/bin/python3'
        end,
      },
      {
        type = 'python',
        request = 'launch',
        name = 'Launch file (cwd = file dir)',
        program = '${file}',
        cwd = '${fileDirname}',
        args = function()
          local args_string = vim.fn.input 'Arguments: '
          local args = {}
          for arg in string.gmatch(args_string, '%S+') do
            table.insert(args, arg)
          end
          return args
        end,
        pythonPath = function()
          local venv = os.getenv 'VIRTUAL_ENV'
          if venv then
            return venv .. '/bin/python'
          end
          return '/usr/bin/python3'
        end,
      },
      {
        type = 'python',
        request = 'launch',
        name = 'Launch from project root (with args)',
        program = '${file}',
        cwd = '${workspaceFolder}',
        args = function()
          local args_string = vim.fn.input 'Arguments: '
          local args = {}
          for arg in string.gmatch(args_string, '%S+') do
            table.insert(args, arg)
          end
          return args
        end,
        pythonPath = function()
          local venv = os.getenv 'VIRTUAL_ENV'
          if venv then
            return venv .. '/bin/python'
          end
          return '/usr/bin/python3'
        end,
      },
    }

    -- JavaScript/TypeScript 설정
    dap.adapters['pwa-node'] = {
      type = 'server',
      host = 'localhost',
      port = '${port}',
      executable = {
        command = 'node',
        args = {
          vim.fn.stdpath 'data' .. '/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js',
          '${port}',
        },
      },
    }

    dap.configurations.javascript = {
      {
        type = 'pwa-node',
        request = 'launch',
        name = 'Launch file',
        program = '${file}',
        cwd = '${workspaceFolder}',
      },
    }
    dap.configurations.typescript = dap.configurations.javascript

    -- C# 설정
    dap.adapters.coreclr = {
      type = 'executable',
      command = vim.fn.stdpath 'data' .. '/mason/packages/netcoredbg/netcoredbg',
      args = { '--interpreter=vscode' },
    }

    dap.configurations.cs = {
      {
        type = 'coreclr',
        request = 'launch',
        name = 'Launch .NET Core',
        program = function()
          return vim.fn.input('Path to dll: ', vim.fn.getcwd() .. '/bin/Debug/', 'file')
        end,
      },
    }
  end,
}
