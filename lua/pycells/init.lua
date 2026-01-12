

local M = {}

M.repl_chan = nil

-- Setup highlighting for cell markers (marker + full-line background)
function M.setup_highlighting(opts)
  opts = opts or {}

  -- Catppuccin-friendly defaults (avoid mauve/mantle)
  local default_dark = {
    marker = { fg = "#4c4f69", bold = true },
    line   = { bg = "#eff1f5" },
  }
  -- Latte-friendly light palette (sky accent, light background)
  local default_light = {
    marker = { fg = "#cdd6f4", bold = true }, -- sky / blue accent
    line   = { bg = "#1e1e2e" },             -- very light latte background
  }

  local defaults = (vim.o.background == "light") and default_light or default_dark
  local marker_opts = opts.marker or defaults.marker
  local line_opts = opts.line or defaults.line

  -- create/apply highlight groups and reapply after colorscheme change
  local function apply_hl()
    vim.api.nvim_set_hl(0, "PyCellMarker", marker_opts)
    vim.api.nvim_set_hl(0, "PyCellLine", line_opts)
  end
  apply_hl()
  vim.api.nvim_create_autocmd("ColorScheme", { callback = apply_hl })

  -- Use a dedicated namespace and buffer-local highlights (robust vs treesitter)
  local ns = vim.api.nvim_create_namespace("pycells_cells")

  local function refresh_buf(bufnr)
    if not vim.api.nvim_buf_is_loaded(bufnr) then return end
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    for i, line in ipairs(lines) do
      local s, e = line:find("#%s*%%+")
      if s then
        -- full-line background
        vim.api.nvim_buf_add_highlight(bufnr, ns, "PyCellLine", i - 1, 0, -1)
        -- highlight just the marker region on top
        vim.api.nvim_buf_add_highlight(bufnr, ns, "PyCellMarker", i - 1, s - 1, e)
      end
    end
  end

  -- Autocommands: refresh on FileType and on buffer changes
  local group = vim.api.nvim_create_augroup("PyCellsHighlight", { clear = false })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "python",
    callback = function(args)
      local bufnr = args.buf
      refresh_buf(bufnr)

      -- refresh highlights for this buffer when it's edited or entered
      vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufEnter", "BufWritePost" }, {
        buffer = bufnr,
        group = group,
        callback = function() refresh_buf(bufnr) end,
      })
    end,
  })
end

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
