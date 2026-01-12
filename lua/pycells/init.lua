

local M = {}

M.repl_chan = nil

-- open side-by-side repl
function M.open_repl(cmd)
  cmd = cmd or "ipython"     -- change to "python" if you want
  vim.cmd("rightbelow vsplit")
  vim.cmd("terminal " .. cmd)
  M.repl_chan = vim.b.terminal_job_id
  vim.cmd("wincmd p")  -- go back to previous window (your code)
end

-- internal: send to repl
local function send(text)
  if not M.repl_chan then
    print("Open REPL first with :PyCellsOpen")
    return
  end
  -- Use terminal bracketed paste so ipython treats the whole chunk as one paste, not line-by-line input.
  local pasted = "\027[200~" .. text .. "\n\027[201~\n"
  vim.fn.chansend(M.repl_chan, pasted)
end

-- run current #%% cell
function M.send_cell()
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  local start = 1
  for i = cur, 1, -1 do
    if lines[i]:match("^%s*#%s*%%+") then
      start = i + 1
      break
    end
  end

  local stop = #lines
  for i = cur + 1, #lines do
    if lines[i]:match("^%s*#%s*%%+") then
      stop = i - 1
      break
    end
  end

  local chunk = table.concat(vim.list_slice(lines, start, stop), "\n")
  send(chunk)
end

-- run visual selection
function M.send_selection()
  local _, ls, cs = unpack(vim.fn.getpos("'<"))
  local _, le, ce = unpack(vim.fn.getpos("'>"))
  local lines = vim.api.nvim_buf_get_lines(0, ls - 1, le, false)
  lines[#lines] = string.sub(lines[#lines], 1, ce)
  lines[1] = string.sub(lines[1], cs)
  send(table.concat(lines, "\n"))
end

-- run current line
function M.send_line()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
  send(line)
end

return M
