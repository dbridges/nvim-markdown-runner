local api = vim.api

local util = {}

function util.readfile_string(p)
  local lines = vim.fn.readfile(p)
  return table.concat(lines, "\n")
end

function util.cookie_path()
  return vim.fn.stdpath("cache") .. "/mdr-cookies.txt"
end

function util.buf_get_line(l)
  return api.nvim_buf_get_lines(0, l-1, l, true)[1]
end

function util.echo_err(msg)
  api.nvim_echo({{"MarkdownRunner: " .. (msg or ""), "ErrorMsg"}}, false, {})
end

return util
