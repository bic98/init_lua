local M = {}

function M.setup(opts)
  opts = opts or {}
  
  -- 기본 설정
  local default_opts = {
    border = "rounded",
    style = "dark",
    width = 120,
    height = math.floor(vim.o.lines * 0.8),
    width_ratio = 0.7,
    height_ratio = 0.7,
  }
  
  -- 사용자 설정과 기본 설정 병합
  for k, v in pairs(default_opts) do
    if opts[k] == nil then
      opts[k] = v
    end
  end
  
  -- 전역 옵션 저장
  M.options = opts
  
  -- Glow 명령어 정의
  vim.api.nvim_create_user_command("Glow", function()
    M.open_preview()
  end, {})
end

function M.open_preview()
  local file = vim.fn.expand('%:p')
  local width = math.floor(vim.o.columns * (M.options.width_ratio or 0.7))
  local height = math.floor(vim.o.lines * (M.options.height_ratio or 0.7))
  
  -- 버퍼 생성
  local buf = vim.api.nvim_create_buf(false, true)
  
  -- 창 옵션 설정
  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = M.options.border,
  }
  
  -- 창 열기
  local win = vim.api.nvim_open_win(buf, true, win_opts)
  
  -- 스타일 설정
  vim.api.nvim_win_set_option(win, "winhl", "Normal:Normal")
  
  -- pandoc으로 HTML 생성 및 표시
  vim.fn.jobstart({"pandoc", "--from=markdown", "--to=html", file}, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data then
        -- HTML을 텍스트로 변환하여 버퍼에 표시
        local lines = {}
        for _, line in ipairs(data) do
          -- HTML 태그 제거 및 간단한 마크다운 스타일 적용
          local text = line:gsub("<[^>]+>", "")
          table.insert(lines, text)
        end
        
        vim.schedule(function()
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
          -- 버퍼 옵션 설정
          vim.api.nvim_buf_set_option(buf, "modifiable", false)
          vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
          vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
          
          -- 종료 매핑
          vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", {noremap = true, silent = true})
        end)
      end
    end
  })
  
  -- 버퍼에 메시지 표시
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"마크다운 프리뷰 로딩 중..."})
end

return M